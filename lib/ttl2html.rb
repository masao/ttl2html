#!/usr/bin/env ruby

require "zlib"
require "uri"
require "yaml"
require "nokogiri"
require "rdf/turtle"
require "ruby-progressbar"

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
      open(file) do |io|
        YAML.safe_load(io, permitted_classes: [Regexp]).each do |k, v|
          config[k.intern] = v
        end
      end
      [ :css_file, :javascript_file ].each do |k|
        if config[k]
          config[k] = [ config[k] ].flatten
        end
      end
      config
    end

    def load_turtle(file)
      STDERR.puts "loading #{file}..."
      count = 0
      if file.end_with?(".gz")
        io = Zlib::GzipReader.open(file)
      else
        io = File.open(file)
      end
      RDF::Format.for(:turtle).reader.new(io) do |reader|
        reader.statements.each do |statement|
          s = statement.subject
          v = statement.predicate
          o = statement.object
          count += 1
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
      STDERR.puts "#{count} triples. #{@data.size} subjects."
      @data
    end
    def format_turtle(subject, depth = 1)
      turtle = RDF::Turtle::Writer.new
      result = ""
      if subject =~ /^_:/
        result << "[\n#{"  "*depth}"
      else
        result << "<#{subject}>\n#{"  "*depth}"
      end
      result << @data[subject.to_s].keys.sort.map do |predicate|
        str = "<#{predicate}> "
        str << @data[subject.to_s][predicate].sort.map do |object|
          if /^_:/ =~ object.to_s # blank node:
            format_turtle(object, depth + 1)
          elsif RDF::URI::IRI =~ object.to_s
            turtle.format_uri(RDF::URI.new object)
          elsif object.respond_to?(:first) and object.first.kind_of?(Symbol)
            turtle.format_literal(RDF::Literal.new(object[1], language: object[0]))
          else
            turtle.format_literal(object)
          end
        end.join(", ")
        str
      end.join(";\n#{"  "*depth}")
      result << " ." if not subject =~ /^_:/
      result << "\n"
      result << "#{"  "*(depth-1)}]" if subject =~ /^_:/
      result
    end
    def format_turtle_inverse(object)
      result = ""
      return result if not object.start_with? @config[:base_uri]
      return result if not @data_inverse.has_key? object
      turtle = RDF::Turtle::Writer.new
      @data_inverse[object].keys.sort.each do |predicate|
        @data_inverse[object.to_s][predicate].sort.each do |subject|
          next if subject =~ /^_:/
          result << "<#{subject}> <#{predicate}> <#{object}>.\n"
        end
      end
      result
    end

    def each_data(label = :each_data)
      progressbar = ProgressBar.create(title: label,
        total: @data.size,
        format: "(%t) %a %e %P% Processed: %c from %C")
      @data.keys.sort_by do|uri|
        [ uri.count("/"), uri.size, uri ] 
      end.reverse_each do |uri|
        progressbar.increment
        next if not uri.start_with? @config[:base_uri]
        yield uri, @data[uri]
      end
      progressbar.finish
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
      each_data(:output_html_files) do |uri, v|
        template = Template.new("default.html.erb", @config)
        param = @config.dup
        param[:uri] = uri
        param[:turtle_uri] = uri + ".ttl"
        param[:data] = v
        param[:data_inverse] = @data_inverse[uri]
        param[:data_inverse_global] = @data_inverse
        param[:data_global] = @data
        param[:title] = template.get_title(v)
        if param[:breadcrumbs]
          param[:breadcrumbs_items] = build_breadcrumbs(uri, template)
        end
        file = uri_mapping_to_path(uri, @config, ".html")
        if @config[:output_dir]
          Dir.mkdir @config[:output_dir] if not File.exist? @config[:output_dir]
          file = File.join(@config[:output_dir], file)
        end
        if template.find_template_path("_default.html.erb")
          param[:additional_content] = template.to_html_raw("_default.html.erb", param)
        end
        template.output_to(file, param)
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
          STDERR.puts "WARN: top_class parameter specified as [#{@config[:top_class]}], but there is no instance data."
        else
          template = Template.new("index.html.erb", @config)
          param = @config.dup
          param[:class_label] = template.get_title(@data[@config[:top_class]], nil)
          param[:data_global] = @data
          param[:data_inverse_global] = @data_inverse
          param[:versions] = versions
          param[:toplevel] = toplevel
          subjects.sort.each do |subject|
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
          template.output_to(index_html, param)
        end
      end
      if template.find_template_path("about.html") or shapes.size > 0 or versions.size > 0 or toplevel.size > 0
        about_html = @config[:about_file] || "about.html"
        about_html =  File.join(@config[:output_dir], about_html) if @config[:output_dir]
        template = Template.new("about.html.erb", @config)
        param = @config.dup
        param[:content] = template.to_html_raw("about.html", {}) if template.find_template_path("about.html")
        param[:data_global] = @data
        param[:versions] = versions
        param[:toplevel] = toplevel
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
              label = template.format_property(target_class)
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
        template.output_to(about_html, param)
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
              path = @data[property]["http://www.w3.org/ns/shacl#path"].first
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
        result = {
          uri: toplevel.to_s,
          description: data["http://purl.org/dc/terms/description"],
          license: license,
          contact: contact,
        }
      end
      result
    end

    def output_turtle_files
      each_data(:output_turtle_files) do |uri, v|
        file = uri_mapping_to_path(uri, @config, ".ttl")
        if @config[:output_dir]
          Dir.mkdir @config[:output_dir] if not File.exist? @config[:output_dir]
          file = File.join(@config[:output_dir], file)
        end
        dir = File.dirname(file)
        FileUtils.mkdir_p(dir) if not File.exist?(dir)
          str = format_turtle(uri)
        str << format_turtle_inverse(uri)
        open(file, "w") do |io|
          io.puts str.strip
        end
      end
    end

    def output_files
      output_html_files
      output_turtle_files if @config[:output_turtle]
    end

    def cleanup
      @data.select do |uri, v|
        uri.start_with? @config[:base_uri]
      end.sort_by do |uri, v|
        -(uri.size)
      end.each do |uri, v|
        html_file = uri_mapping_to_path(uri, @config, ".html")
        html_file = File.join(@config[:output_dir], html_file) if @config[:output_dir]
        File.unlink html_file if File.exist? html_file
        ttl_file = uri_mapping_to_path(uri, @config, ".ttl")
        ttl_file = File.join(@config[:output_dir], ttl_file) if @config[:output_dir]
        File.unlink ttl_file if File.exist? ttl_file
        dir = uri.sub(@config[:base_uri], "")
        dir = File.join(@config[:output_dir], dir) if @config[:output_dir]
        Dir.rmdir dir if File.exist? dir
      end
      index_html = "index.html"
      index_html = File.join(@config[:output_dir], "index.html") if @config[:output_dir]
      if @config[:top_class] and File.exist? index_html
        File.unlink index_html
      end
    end
  end

  def find_turtle(filename, params = {})
    if params[:noexpand] == true
      filename if File.exists? filename
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
