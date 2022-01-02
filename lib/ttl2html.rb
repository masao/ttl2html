#!/usr/bin/env ruby

require "zlib"
require "yaml"
require "nokogiri"
require "rdf/turtle"
require "ruby-progressbar"

require "ttl2html/template"

module TTL2HTML
  class App
    def initialize(config = "config.yml")
      @config = load_config(config)
      if not @config[:base_uri]
        raise "load_config: base_uri not found"
      end
      @data = {}
      @data_inverse = {}
      @prefix = {}
      @graph = RDF::Graph.new
    end

    def load_config(file)
      config = {}
      open(file) do |io|
        YAML.safe_load(io, permitted_classes: [Regexp]).each do |k, v|
          config[k.intern] = v
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
      RDF::Turtle::Reader.new(io) do |reader|
        @prefix.merge! reader.prefixes
        reader.statements.each do |statement|
          @graph.insert(statement)
          s = statement.subject
          v = statement.predicate
          o = statement.object
          count += 1
          @data[s.to_s] ||= {}
          if o.respond_to?(:has_language?) and o.has_language?
            @data[s.to_s][v.to_s] ||= {}
            @data[s.to_s][v.to_s][o.language] = o.to_s
          else
            @data[s.to_s][v.to_s] ||= []
            @data[s.to_s][v.to_s] << o.to_s
          end
          if o.is_a? RDF::URI
            @data_inverse[o.to_s] ||= {}
            @data_inverse[o.to_s][v.to_s] ||= []
            @data_inverse[o.to_s][v.to_s] << s.to_s
          end
        end
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
          if object =~ /^_:/ # blank node:
            format_turtle(object, depth + 1)
          elsif object =~ RDF::URI::IRI
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
      @data.each do |uri, v|
        progressbar.increment
        next if not uri.start_with? @config[:base_uri]
        yield uri, v
      end
      progressbar.finish
    end
    def output_html_files
      template = Template.new("", @config)
      shapes = @graph.query([nil,
                             RDF::URI("http://www.w3.org/1999/02/22-rdf-syntax-ns#type"),
                             RDF::URI("http://www.w3.org/ns/shacl#NodeShape")])
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
        param[:turtle_uri] = uri_mapping_to_path(uri, ".ttl")
        param[:data] = v
        param[:data_inverse] = @data_inverse[uri]
        param[:data_global] = @data
        param[:title] = template.get_title(v)
        if param[:breadcrumbs]
          param[:breadcrumbs_items] = build_breadcrumbs(uri, template)
        end
        file = uri_mapping_to_path(uri, ".html")
        if @config[:output_dir]
          Dir.mkdir @config[:output_dir] if not File.exist? @config[:output_dir]
          file = File.join(@config[:output_dir], file)
        end
        template.output_to(file, param)
      end
      index_html = "index.html"
      index_html = File.join(@config[:output_dir], "index.html") if @config[:output_dir]
      if @config.has_key? :top_class
        subjects = @graph.query([nil,
                                RDF::URI("http://www.w3.org/1999/02/22-rdf-syntax-ns#type"),
                                RDF::URI(@config[:top_class])]).subjects
        if subjects.empty?
          STDERR.puts "WARN: top_class parameter specified as [#{@config[:top_class]}], but there is no instance data."
          STDERR.puts "  Skip generation of top page."
        else
          template = Template.new("index.html.erb", @config)
          param = @config.dup
          param[:data_global] = @data
          param[:versions] = versions
          param[:toplevel] = toplevel
          subjects.sort.each do |subject|
            param[:index_data] ||= []
            param[:index_data] << subject.to_s
          end
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
        shapes.subjects.each do |subject|
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
          param[:shapes][subject] = {
            label: label,
            comment: comment,
            html: template.expand_shape(@data, subject.to_s, @prefix),
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
          if data_target and data_target[e["property"]]
            data_target[e["property"]].each do |parent|
              data_parent = @data[parent]
              label = template.get_title(data_parent)
              label = data_parent[e["label"]].first if e["label"] and data_parent[e["label"]]
              results << {
                uri: parent,
                label: label,
              }
              results += build_breadcrumbs(parent, template, depth + 1)
            end
            return results
          end
        end
      end
      results
    end

    def shapes2labels(shapes)
      labels = {}
      shapes.subjects.each do |shape|
        target_class = @data[shape.to_s]["http://www.w3.org/ns/shacl#targetClass"]&.first
        if target_class
          @data[shape.to_s]["http://www.w3.org/ns/shacl#property"].each do |property|
            path = @data[property]["http://www.w3.org/ns/shacl#path"].first
            name = @data[property]["http://www.w3.org/ns/shacl#name"]
            labels[target_class] ||= {}
            labels[target_class][path] = name
          end
        end
      end
      labels
    end
    def shapes2orders(shapes)
      orders = {}
      shapes.subjects.each do |shape|
        target_class = @data[shape.to_s]["http://www.w3.org/ns/shacl#targetClass"]&.first
        if target_class
          @data[shape.to_s]["http://www.w3.org/ns/shacl#property"].each do |property|
            path = @data[property]["http://www.w3.org/ns/shacl#path"].first
            order = @data[property]["http://www.w3.org/ns/shacl#order"]
            orders[target_class] ||= {}
            orders[target_class][path] = order&.first&.to_i
          end
        end
      end
      orders
    end

    def extract_versions
      versions = []
      ["http://purl.org/pav/hasVersion", "http://purl.org/pav/hasCurrentVersion", "http://purl.org/dc/terms/hasVersion"].each do |prop|
        objects = @graph.query([nil, RDF::URI(prop), nil]).objects
        objects.each do |o|
          uri = o.to_s
          version = @data[uri]
          next if not version
          next if not version["http://www.w3.org/1999/02/22-rdf-syntax-ns#type"].include? "http://rdfs.org/ns/void#Dataset"
          description = version["http://purl.org/dc/terms/description"]
          link = nil
          if not description
            qrev = version["http://www.w3.org/ns/prov#qualifiedRevision"]&.first
            if @data[qrev]
              description = @data[qrev]["http://www.w3.org/2000/01/rdf-schema#comment"]
              link = @data[qrev]["http://www.w3.org/2000/01/rdf-schema#seeAlso"]&.first
            end
          end
          subset = []
          if version["http://rdfs.org/ns/void#subset"]
            version["http://rdfs.org/ns/void#subset"].each do |s|
              subset << @data[s]["http://rdfs.org/ns/void#dataDump"].first
            end
          end
          date = version["http://purl.org/pav/createdOn"]&.first
          date = version["http://purl.org/dc/terms/issued"]&.first if date.nil?
          versions << {
            uri: uri,
            version: version["http://purl.org/pav/version"]&.first,
            triples: version["http://rdfs.org/ns/void#triples"]&.first,
            datadump: version["http://rdfs.org/ns/void#dataDump"]&.first,
            bytesize: version["http://www.w3.org/ns/dcat#byteSize"]&.first,
            date: date,
            description: description,
            subset: subset,
            link: link,
          }
        end
      end
      versions.sort_by{|v| [ v[:date], v[:uri] ] }
    end
    def extract_toplevel
      result = {}
      toplevel = @graph.query([nil, RDF::URI("http://purl.org/pav/hasCurrentVersion"), nil]).subjects.first
      data  = @data[toplevel.to_s]
      if toplevel
        license = {}
        if data["http://purl.org/dc/terms/license"]
          license_data = @data[data["http://purl.org/dc/terms/license"].first]
          license[:url] = license_data["http://www.w3.org/1999/02/22-rdf-syntax-ns#value"]&.first
          license[:icon] = license_data["http://xmlns.com/foaf/0.1/thumbnail"]&.first
          license[:label] = license_data["http://www.w3.org/2000/01/rdf-schema#label"]
        end
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
        file = uri_mapping_to_path(uri, ".ttl")
        if @config[:output_dir]
          Dir.mkdir @config[:output_dir] if not File.exist? @config[:output_dir]
          file = File.join(@config[:output_dir], file)
        end
        str = format_turtle(uri)
        str << format_turtle_inverse(uri)
        open(file, "w") do |io|
          io.puts str.strip
        end
      end
    end
    def uri_mapping_to_path(uri, suffix = ".html")
      path = nil
      if @config[:uri_mappings]
        @config[:uri_mappings].each do |mapping|
          local_file = uri.sub(@config[:base_uri], "")
          if mapping["regexp"] =~ local_file
            path = local_file.sub(mapping["regexp"], mapping["path"])
          end
        end
      end
      if path.nil?
        if suffix == ".html"
          if @data.keys.find{|e| e.start_with?(uri + "/") }
            path = uri + "/index"
          elsif uri.end_with?("/")
            path = uri + "index"
          else
            path = uri
          end
        else
          path = uri
        end
      end
      path = path.sub(@config[:base_uri], "")
      path << suffix
      #p [uri, path]
      path
    end
    def cleanup
      @data.select do |uri, v|
        uri.start_with? @config[:base_uri]
      end.sort_by do |uri, v|
        -(uri.size)
      end.each do |uri, v|
        html_file = uri_mapping_to_path(uri, ".html")
        html_file = File.join(@config[:output_dir], html_file) if @config[:output_dir]
        File.unlink html_file
        ttl_file = uri_mapping_to_path(uri, ".ttl")
        ttl_file = File.join(@config[:output_dir], ttl_file) if @config[:output_dir]
        File.unlink ttl_file
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
