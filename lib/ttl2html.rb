#!/usr/bin/env ruby

require "zlib"
require "uri"
require "yaml"
require "nokogiri"
require "rdf/turtle"
require "ruby-progressbar"
require "parallel"

require "ttl2html/util"
require "ttl2html/template"
require "ttl2html/version"

module TTL2HTML
  class App
    include Util
    def initialize(config = "config.yml")
      @config = load_config(config)
      if not @config[:base_uri]
        raise "load_config: base_uri not found"
      end
      @data = {}
      @data_inverse = {}
      @prefix = {}
    end

    def load_config(file)
      config = { output_turtle: true }
      File.open(file) do |io|
        YAML.safe_load(io, permitted_classes: [Regexp]).each do |k, v|
          config[k.intern] = v
        end
      end
      [ :css_file, :javascript_file ].each do |k|
        if config[k]
          config[k] = Array(config[k]).flatten
        end
      end
      config
    end

    def load_turtle(file)
      $stderr.puts "loading #{file}..."
      count = 0
      subjects = Set.new
      if file.end_with?(".gz")
        io = Zlib::GzipReader.open(file)
      else
        io = File.open(file)
      end
      RDF::Format.for(:turtle).reader.new(io) do |reader|
        reader.each_statement do |statement|
          s = statement.subject
          v = statement.predicate
          o = statement.object
          count += 1
          subjects << s
          @data[s.to_s] ||= {}
          @data[s.to_s][v.to_s] ||= []
          if o.is_a? RDF::URI or o.is_a? RDF::Node
            @data[s.to_s][v.to_s] << o.to_s
            @data_inverse[o.to_s] ||= {}
            @data_inverse[o.to_s][v.to_s] ||= []
            @data_inverse[o.to_s][v.to_s] << s.to_s
          else
            @data[s.to_s][v.to_s] << o
          end
        end
        @prefix.merge! reader.prefixes
      end
      $stderr.puts "#{count} triples. #{subjects.size} subjects."
      @data
    end

    QB_ORDER_URI = "http://purl.org/linked-data/cube#order"
    SCHEMA_POSITION_URI = "http://schema.org/position"
    SCHEMA_POSITION_URI_S = "https://schema.org/position"
    SHACL_ORDER_URI = "http://www.w3.org/ns/shacl#order"
    def sort_key_for_resource(resource)
      qb_order = Float::INFINITY
      schema_position = Float::INFINITY
      shacl_order = Float::INFINITY
      if @data[resource.to_s]
        qb_order = @data[resource.to_s][QB_ORDER_URI].first.to_i if @data[resource.to_s][QB_ORDER_URI]
        schema_position = @data[resource.to_s][SCHEMA_POSITION_URI].first.to_i if @data[resource.to_s][SCHEMA_POSITION_URI]
        schema_position = @data[resource.to_s][SCHEMA_POSITION_URI_S].first.to_i if @data[resource.to_s][SCHEMA_POSITION_URI_S]
        shacl_order = @data[resource.to_s][SHACL_ORDER_URI].first.to_i if @data[resource.to_s][SHACL_ORDER_URI]
      end
      if resource.to_s =~ /^_:/ and @data[resource.to_s]
        resource_str = "{" + @data[resource.to_s].sort_by do |p, o|
          [p, o]
        end.join("\t") + "}"
        [ schema_position, qb_order, shacl_order, resource_str ]
      else
        [ schema_position, qb_order, shacl_order, resource.to_s ]
      end
    end
    def format_uri(uri)
      @turtle_writer ||= RDF::Turtle::Writer.new(nil, prefixes: @prefix)
      @turtle_writer.format_uri(RDF::URI(uri))
    end
    def format_turtle(subject, depth = 1, force = false)
      @turtle_writer ||= RDF::Turtle::Writer.new(nil, prefixes: @prefix)
      result = ""
      #p [:format_turtle, subject, depth, force]
      return result if !force && @cache[:output_turtle_files].include?(subject)
      if subject =~ /^_:/
        result << "[\n#{"  "*depth}"
      else
        result << format_uri(subject) << "\n#{"  "*depth}"
      end
      result << @data[subject.to_s].keys.sort.map do |predicate|
        str = format_uri(predicate) << " "
        #p [subject, predicate, @data[subject.to_s][predicate]]
        str << @data[subject.to_s][predicate].sort_by do |object|
          #p [subject, predicate, object, depth]
          sort_key_for_resource(object)
        end.map do |object|
          if /^_:/ =~ object.to_s # blank node:
            format_turtle(object, depth + 1, force)
          elsif RDF::URI::IRI =~ object.to_s
            format_uri(object)
          else
            @turtle_writer.format_literal(object)
          end
        end.join(", ")
        str
      end.join(";\n#{"  "*depth}")
      result << "." if not subject =~ /^_:/
      result << "\n"
      result << "#{"  "*(depth-1)}]" if subject =~ /^_:/
      @cache[:output_turtle_files] << subject unless force
      result
    end
    def format_turtle_inverse(object)
      triples = collect_inverse_triples(object)
      return "" if triples.empty?
      by_subject = build_subject_index(triples)
      ref_count  = build_object_ref_count(triples)
      roots      = find_inverse_roots(by_subject)
      roots.map do |root|
        "#{format_inverse_subject(root, by_subject, ref_count, Set.new, 1)}.\n"
      end.join
    end
    def collect_inverse_triples(object, triples = Set.new, visited = Set.new)
      return triples if object.to_s.start_with?("_:")
      return triples unless object.to_s.start_with?(@config[:base_uri].to_s)
      return triples unless @data_inverse.key?(object.to_s)
      return triples if visited.include?(object.to_s)
      visited << object.to_s
      @data_inverse[object.to_s].each do |predicate, subjects|
        subjects.each do |subject|
          triples << [subject.to_s, predicate.to_s, object.to_s]
          collect_inverse_triples_for_bnode(subject.to_s, triples, visited) if subject.to_s.start_with?("_:")
        end
      end
      triples
    end
    def collect_inverse_triples_for_bnode(node, triples, visited)
      return triples unless @data_inverse.key?(node)
      return triples if visited.include?(node)
      visited << node
      @data_inverse[node].each do |predicate, subjects|
        subjects.each do |subject|
            triples << [subject.to_s, predicate.to_s, node]
            collect_inverse_triples_for_bnode(subject.to_s, triples, visited) if subject.to_s.start_with?("_:")
        end
      end
      triples
    end
    def build_subject_index(triples)
      by_subject = Hash.new { |h, k| h[k] = Hash.new { |hh, kk| hh[kk] = [] } }
      triples.each do |subject, predicate, object|
        by_subject[subject][predicate] << object
      end
      by_subject.each_value do |predicates|
        predicates.each_value(&:uniq!)
      end
      by_subject
    end
    def build_object_ref_count(triples)
      count = Hash.new(0)
      triples.each do |_subject, _predicate, object|
        count[object] += 1 if object.to_s.start_with?("_:")
      end
      count
    end
    def find_inverse_roots(by_subject)
      all_subjects = by_subject.keys
      all_objects  = by_subject.values.flat_map { |preds| preds.values.flatten }.uniq
      all_subjects.reject do |subject|
        subject.start_with?("_:") || all_objects.include?(subject)
      end.sort
    end
    def format_inverse_subject(subject, by_subject, ref_count, visited, depth = 1)
      props = by_subject[subject]
      return format_node(subject) if props.nil? || props.empty?
      indent = "  " * (depth - 1)
      inner  = "  " * depth
      if subject.start_with?("_:")
        return "[]" if visited.include?(subject)
        visited = visited.dup
        visited << subject
        head = "[\n#{inner}"
        tail = "\n#{indent}]"
      else
        head = format_uri(subject) << " "
        tail = ""
      end
      body = props.keys.sort.map do |predicate|
        objects = props[predicate].sort.map do |object|
          format_inverse_object(object, by_subject, ref_count, visited, depth + 1)
        end.join(", ")
        format_uri(predicate) << " " << objects
      end.join(";\n#{inner}")
      head + body + tail
    end
    def format_inverse_object(object, by_subject, ref_count, visited, depth = 1)
      if object.to_s.start_with?("_:") && by_subject.key?(object.to_s)
        if ref_count[object.to_s] <= 1
          format_inverse_subject(object.to_s, by_subject, ref_count, visited, depth)
        else
          object.to_s
        end
      else
        format_node(object)
      end
    end
    def format_node(value)
      @turtle_writer ||= RDF::Turtle::Writer.new(nil, prefixes: @prefix)
      if value.to_s.start_with?("_:")
        value.to_s
      elsif RDF::URI::IRI =~ value.to_s
        format_uri(value)
      else
        @turtle_writer.format_literal(value)
      end
    end

    def each_data(label = :each_data)
      progressbar_options = {
        output: $stderr,
        title: label.to_s,
        format: "(%t) %a %e %P% Processed: %c from %C"
      }
      data = @data.keys.sort_by do|uri|
        local_path = uri_mapping_to_path(uri, @config, ".html")
        #p [ local_path.size, local_path.count("/"), local_path ]
        [ -(local_path.count("/")), -(local_path.size), local_path ]
      end
      Parallel.each(data, progress: progressbar_options) do |uri|
        next if not uri.start_with? @config[:base_uri]
        yield uri, @data[uri]
      end
    end
    def output_html_files
      template = Template.new("", @config)
      shapes = []
      @data.each do |s, v|
        if v[RDF.type.to_s] and @data[s][RDF.type.to_s].include?("http://www.w3.org/ns/shacl#NodeShape")
          shapes << s
        end
      end
      labels = shapes2labels(shapes)
      versions = extract_versions
      toplevel = extract_toplevel
      about_required = template.find_template_path("about.html") || !shapes.empty? || !versions.empty? || !toplevel.empty?
      about_file = (@config[:about_file] || "about.html") if about_required
      @config[:labels_with_class] ||= {}
      labels.each do |klass, props|
        props.each do |property, label|
          @config[:labels_with_class][klass] ||= {}
          if @config[:labels_with_class][klass][property]
            next
          else
            @config[:labels_with_class][klass][property] = template.get_language_literal(label)
          end
        end
      end
      @config[:orders_with_class] = shapes2orders(shapes)
      FileUtils.mkdir_p(@config[:output_dir]) if @config[:output_dir]
      template = Template.new("default.html.erb", @config)
      each_data(:output_html_files) do |uri, v|
        param = @config.dup
        param[:uri] = uri
        param[:turtle_uri] = uri + ".ttl"
        param[:data] = v
        param[:data_inverse] = @data_inverse[uri]
        param[:data_inverse_global] = @data_inverse
        param[:data_global] = @data
        param[:title] = template.get_title(v)
        if @config[:subtitle_property] or @config[:subtitle_property_perclass]
          param[:subtitle] = template.get_subtitle(v)
        end
        if param[:breadcrumbs]
          param[:breadcrumbs_items] = build_breadcrumbs(uri, template)
        end
        file = uri_mapping_to_path(uri, @config, ".html")
        #p [:each_data, uri, file]
        if @config[:output_dir]
          file = File.join(@config[:output_dir], file)
        end
        file = safe_output_path(file)
        if file
          if template.find_template_path("_default.html.erb")
            param[:additional_content] = template.to_html_raw("_default.html.erb", param)
          end
          param[:about_file] = about_file if about_required
          template.output_to(file, param)
        end
      end
      index_html = "index.html"
      index_html = File.join(@config[:output_dir], "index.html") if @config[:output_dir]
      if @config.has_key? :top_class
        subjects = []
        @data.each do |s, v|
          if @data[s][RDF.type.to_s] and @data[s][RDF.type.to_s].include?(@config[:top_class])
            subjects << s
          end
        end
        if subjects.empty?
          $stderr.puts "WARN: top_class parameter specified as [#{@config[:top_class]}], but there is no instance data."
        else
          template = Template.new("index.html.erb", @config)
          param = @config.dup
          param[:class_label] = template.get_title(@data[@config[:top_class]], nil)
          param[:class_label] ||= @config[:top_class].split(/[\/\#]/).last.capitalize
          param[:data_global] = @data
          param[:data_inverse_global] = @data_inverse
          param[:versions] = versions
          param[:toplevel] = toplevel
          param[:description] = template.to_html_raw("description.html", {}) if template.find_template_path("description.html")
          subjects.sort_by do |subject|
            sort_key_for_resource(subject)
          end.each do |subject|
            objects = []
            if @config.has_key? :top_additional_property
              @config[:top_additional_property].each do |property|
                if @data[subject][property]
                  objects += @data[subject][property]
                end
              end
            end
            param[:index_data] ||= []
            param[:index_data] << {
              subject.to_s => objects
            }
          end
          param[:output_file] = index_html
          param[:index_list] = template.to_html_raw("index-list.html.erb", param)
          param[:about_file] = about_file if about_required
          index_html = safe_output_path(index_html)
          template.output_to(index_html, param) if index_html
        end
      end
      if about_required
        about_html = about_file
        about_html =  File.join(@config[:output_dir], about_html) if @config[:output_dir]
        template = Template.new("about.html.erb", @config)
        param = @config.dup
        param[:about_file] = about_file
        param[:content] = template.to_html_raw("about.html", {}) if template.find_template_path("about.html")
        param[:data_global] = @data
        param[:versions] = versions
        param[:toplevel] = toplevel
        param[:description] = template.to_html_raw("description.html", {}) if template.find_template_path("description.html")
        param[:shapes] = {}
        shapes.each do |subject|
          orders = []
          if param[:shape_orders]
            param[:shape_orders].index(subject)
            orders << ( param[:shape_orders].index(subject) or Float::INFINITY )
          end
          orders << subject
          label = comment = nil
          target_class = @data[subject.to_s]["http://www.w3.org/ns/shacl#targetClass"]
          if target_class
            target_class = target_class.first
            if @data[target_class]
              label = template.get_title(@data[target_class], nil)
              comment = template.get_language_literal(@data[target_class]["http://www.w3.org/2000/01/rdf-schema#comment"]) if @data[target_class]["http://www.w3.org/2000/01/rdf-schema#comment"]
            else
              label = template.format_property(target_class, param)
            end
          else
            label = template.get_title(@data[subject.to_s])
          end
          html = template.expand_shape(@data, subject.to_s, @prefix)
          next if html.nil?
          param[:shapes][subject] = {
            label: label,
            comment: comment,
            html: html,
            target_class: target_class,
            order: orders,
          }
        end
        about_html = safe_output_path(about_html)
        template.output_to(about_html, param) if about_html
      end
    end

    def build_breadcrumbs(uri, template, depth = 0)
      results = []
      data = @data[uri]
      if @config[:breadcrumbs]
        if depth == 0
          first_label = template.get_title(data)
          first_label = data[@config[:breadcrumbs].first["label"]].first if @config[:breadcrumbs].first["label"] and data[@config[:breadcrumbs].first["label"]]
          results << { label: first_label }
        end
        @config[:breadcrumbs].each do |e|
          data_target = data
          data_target = @data_inverse[uri] if e["inverse"]
          if data_target
            if e["property"].kind_of? Array
              parent = nil
              data_target_sub = data_target
              e["property"].each do |prop|
                if data_target_sub[prop["property"]]
                  data_target_sub[prop["property"]].each do |o|
                    parent = o
                    data_target_sub = @data[parent]
                  end
                end
              end
              if parent
                results << build_breadcrumbs_sub(parent, template)
                results += build_breadcrumbs(parent, template, depth + 1)
                return results
              end
            elsif data_target[e["property"]]
              data_target[e["property"]].each do |parent|
                results << build_breadcrumbs_sub(parent, template, e["label"])
                results += build_breadcrumbs(parent, template, depth + 1)
                return results
              end
            end
          end
        end
      end
      results
    end
    def build_breadcrumbs_sub(parent, template, label_prop = nil)
      data_parent = @data[parent]
      label = template.get_title(data_parent)
      label = data_parent[label_prop].first if label_prop and data_parent[label_prop]
      {
        uri: parent,
        label: label,
      }
    end

    def shapes_parse(shapes)
      shapes.each do |shape|
        target_class = @data[shape]["http://www.w3.org/ns/shacl#targetClass"]&.first
        if target_class
          properties = @data[shape.to_s]["http://www.w3.org/ns/shacl#property"]
          if @data[shape.to_s]["http://www.w3.org/ns/shacl#or"]
            properties ||= []
            node_list = @data[shape.to_s]["http://www.w3.org/ns/shacl#or"].first
            while node_list and @data[node_list] do
              sub_shape = @data[node_list]["http://www.w3.org/1999/02/22-rdf-syntax-ns#first"].first
              if @data[sub_shape] and @data[sub_shape]["http://www.w3.org/ns/shacl#property"]
                properties += @data[sub_shape]["http://www.w3.org/ns/shacl#property"]
              end
              node_list = @data[node_list]["http://www.w3.org/1999/02/22-rdf-syntax-ns#rest"].first
            end
          end
          if not properties.empty?
            properties.each do |property|
              yield target_class, property
            end
          end
        end
      end
    end
    def shapes2labels(shapes)
      labels = {}
      shapes_parse(shapes) do |target_class, property|
        path = @data[property]["http://www.w3.org/ns/shacl#path"].first
        name = @data[property]["http://www.w3.org/ns/shacl#name"]
        labels[target_class] ||= {}
        labels[target_class][path] = name
      end
      labels
    end
    def shapes2orders(shapes)
      orders = {}
      shapes_parse(shapes) do |target_class, property|
        path = @data[property]["http://www.w3.org/ns/shacl#path"].first
        order = @data[property]["http://www.w3.org/ns/shacl#order"]
        orders[target_class] ||= {}
        orders[target_class][path] = order&.first&.to_i
      end
      orders
    end

    def extract_version_metadata(data)
      description = data["http://purl.org/dc/terms/description"]
      link = nil
      if not description
        qrev = data["http://www.w3.org/ns/prov#qualifiedRevision"]&.first
        if @data[qrev]
          description = @data[qrev]["http://www.w3.org/2000/01/rdf-schema#comment"]
          link = @data[qrev]["http://www.w3.org/2000/01/rdf-schema#seeAlso"]&.first
        end
      end
      subset = []
      if data["http://rdfs.org/ns/void#subset"]
        data["http://rdfs.org/ns/void#subset"].each do |s|
          abort "#{s} not found" if not @data[s]
          subset << extract_version_metadata(@data[s])
        end
      end
      date = data["http://purl.org/pav/createdOn"]&.first
      date = data["http://purl.org/dc/terms/issued"]&.first if date.nil?
      return {
        version: data["http://purl.org/pav/version"]&.first,
        triples: data["http://rdfs.org/ns/void#triples"]&.first,
        datadump: data["http://rdfs.org/ns/void#dataDump"]&.first,
        bytesize: data["http://www.w3.org/ns/dcat#byteSize"]&.first,
        date: date,
        description: description,
        subset: subset,
        link: link,
        license: extract_license(data),
        derivedfrom: extract_derivedfrom(data),
      }
    end
    def extract_versions
      versions = []
      ["http://purl.org/pav/hasVersion", "http://purl.org/pav/hasCurrentVersion", "http://purl.org/dc/terms/hasVersion"].each do |prop|
        objects = []
        @data.each do |s, v|
          if @data[s][prop]
            objects += @data[s][prop]
          end
        end
        objects.each do |o|
          uri = o.to_s
          version = @data[uri]
          next if not version
          next if not version["http://www.w3.org/1999/02/22-rdf-syntax-ns#type"]
          next if not version["http://www.w3.org/1999/02/22-rdf-syntax-ns#type"].include? "http://rdfs.org/ns/void#Dataset"
          versions << extract_version_metadata(version)
        end
      end
      versions.sort_by{|v| [ v[:date], v[:version] ] }
    end
    def extract_derivedfrom(data)
      derivedfrom = {}
      wasDerivedFrom = data["http://www.w3.org/ns/prov#wasDerivedFrom"]&.first
      if @data[wasDerivedFrom]
        derivedfrom = {
          url: @data[wasDerivedFrom]["http://www.w3.org/1999/02/22-rdf-syntax-ns#value"]&.first,
          label: @data[wasDerivedFrom]["http://www.w3.org/2000/01/rdf-schema#label"]
        }
      end
      derivedfrom
    end
    def extract_license(data)
      license = {}
      if data["http://purl.org/dc/terms/license"]
        license_data = @data[data["http://purl.org/dc/terms/license"].first]
        if license_data
          license[:url] = license_data["http://www.w3.org/1999/02/22-rdf-syntax-ns#value"]&.first
          license[:icon] = license_data["http://xmlns.com/foaf/0.1/thumbnail"]&.first
          license[:label] = license_data["http://www.w3.org/2000/01/rdf-schema#label"]
        elsif data["http://purl.org/dc/terms/license"].first =~ URI::regexp
          license[:url] = license[:label] = data["http://purl.org/dc/terms/license"].first
        end
      end
      license
    end
    def extract_toplevel
      result = {}
      toplevel = nil
      @data.each do |s, v|
        if @data[s]["http://purl.org/pav/hasCurrentVersion"]
          toplevel = s
        end
      end
      data  = @data[toplevel.to_s]
      if toplevel
        license = extract_license(data)
        derivedfrom = extract_derivedfrom(data)
        if data["http://purl.org/dc/terms/publisher"]
          publisher_data = @data[data["http://purl.org/dc/terms/publisher"].first]
          email = publisher_data["http://xmlns.com/foaf/0.1/mbox"]&.first
          contact = { email: email }
          name = publisher_data["http://xmlns.com/foaf/0.1/name"]
          contact[:name] = name if name
          members = []
          if publisher_data["http://xmlns.com/foaf/0.1/member"]
            publisher_data["http://xmlns.com/foaf/0.1/member"].each do |member|
              member_data = @data[member]
              members << {
                name: member_data["http://xmlns.com/foaf/0.1/name"],
                org: member_data["http://www.w3.org/2006/vcard/ns#organization-name"]
              }
            end
            contact[:members] = members
          end
        end
        if data["http://rdfs.org/ns/void#sparqlEndpoint"]
          endpoint = data["http://rdfs.org/ns/void#sparqlEndpoint"].first
        end
        if data["http://www.w3.org/ns/dcat#accessService"]
          service = data["http://www.w3.org/ns/dcat#accessService"].first
          service_data = @data[service]
          if service_data
            endpoint = service_data["http://www.w3.org/ns/dcat#endpointURL"]&.first
            endpoint_landingpage = service_data["http://www.w3.org/ns/dcat#landingPage"]&.first
          end
        end
        result = {
          uri: toplevel.to_s,
          description: data["http://purl.org/dc/terms/description"],
          license: license,
          contact: contact,
          endpoint: endpoint,
          endpoint_landingpage: endpoint_landingpage,
          derivedfrom: derivedfrom,
        }
      end
      result
    end

    def output_turtle_files
      FileUtils.mkdir_p(@config[:output_dir]) if @config[:output_dir]
      each_data(:output_turtle_files) do |uri, v|
        file = uri_mapping_to_path(uri, @config, ".ttl")
        if @config[:output_dir]
          file = File.join(@config[:output_dir], file)
        end
        file = safe_output_path(file)
        next if not file
        dir = File.dirname(file)
        FileUtils.mkdir_p(dir) if not File.exist?(dir)
        @cache ||= {}
        @cache[:output_turtle_files] = Set.new
        str = format_turtle(uri)
        str << format_turtle_inverse(uri)
        File.open(file, "w") do |io|
          @prefix.each do |prefix, namespace|
            io.puts "@prefix #{prefix}: <#{namespace}>."
          end
          io.puts str.strip
        end
      end
    end

    def output_files
      output_html_files
      output_turtle_files if @config[:output_turtle]
    end

    def cleanup
      dirs = []
      @data.select do |uri, v|
        uri.start_with? @config[:base_uri]
      end.sort_by do |uri, v|
        -(uri.size)
      end.each do |uri, v|
        html_file = uri_mapping_to_path(uri, @config, ".html")
        html_file = File.join(@config[:output_dir], html_file) if @config[:output_dir]
        html_file = safe_output_path(html_file)
        if html_file and File.file? html_file
          dirs << File.dirname(html_file)
          File.unlink html_file
        end
        ttl_file = uri_mapping_to_path(uri, @config, ".ttl")
        ttl_file = File.join(@config[:output_dir], ttl_file) if @config[:output_dir]
        ttl_file = safe_output_path(ttl_file)
        if ttl_file and File.file? ttl_file
          dirs << File.dirname(ttl_file)
          File.unlink ttl_file
        end
      end
      index_html = "index.html"
      index_html = File.join(@config[:output_dir], "index.html") if @config[:output_dir]
      index_html = safe_output_path(index_html)
      if index_html and @config[:top_class] and File.file? index_html
        File.unlink index_html
      end
      about_html = (@config[:about_file] || "about.html")
      about_html = File.join(@config[:output_dir], about_html) if @config[:output_dir]
      about_html = safe_output_path(about_html)
      if about_html and File.file? about_html
        File.unlink about_html
      end

      dirs = dirs.uniq.sort_by{|e| -(e.size) }
      #p dirs
      dirs.each do |dir|
        dir = safe_output_path(dir)
        next unless dir
        next if dir == File.expand_path(".") # failsafe...
        next if @config[:output_dir] and dir == File.expand_path(@config[:output_dir]) # failsafe...
        if dir and File.exist?(dir) and File.directory?(dir)
          FileUtils.remove_entry_secure(dir)
        end
      end
    end
  end

  def find_turtle(filename, params = {})
    if params[:noexpand] == true
      if File.exist? filename
        filename
      else
        nil
      end
    else
      file = nil
      basename = File.basename(filename, ".ttl")
      dirname = File.dirname(filename)
      files = Dir.glob("#{dirname}/#{basename}-[0-9]*.ttl{,.gz}")
      file = files.sort.last
      file
    end
  end
end
