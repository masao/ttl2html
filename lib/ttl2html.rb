#!/usr/bin/env ruby

require "yaml"
require "nokogiri"
require "rdf/turtle"
require "ruby-progressbar"

require "ttl2html/template"

module TTL2HTML
  class App
    using ProgressBar::Refinements::Enumerator
    def initialize(config = "config.yml")
      @template = {}
      @config = load_config(config)
      if not @config[:base_uri]
        raise "load_config: base_uri not found"
      end
      @data = {}
      @data_inverse = {}
      @graph = RDF::Graph.new
    end

    def load_config(file)
      config = {}
      YAML.load_file(file).each do |k, v|
        config[k.intern] = v
      end
      config
    end

    def load_turtle(file)
      STDERR.puts "loading #{file}..."
      count = 0
      RDF::Turtle::Reader.open(file) do |reader|
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
      if subject.iri?
        result << "<#{subject}>\n#{"  "*depth}"
      else
        result << "[\n#{"  "*depth}"
      end
      result << @graph.query([subject, nil, nil]).predicates.sort.map do |predicate|
        str = "<#{predicate}> "
        str << @graph.query([subject, predicate, nil]).objects.sort_by do |object|
          if object.resource? and not object.iri? # blank node:
            @graph.query([object, nil, nil]).statements.sort_by{|e|
              [ e.predicate, e.object ]
            }.map{|e|
              [ e.predicate, e.object ]
            }
          else
            object
          end
        end.map do |object|
          if object.resource? and not object.iri? # blank node:
            format_turtle(object, depth + 1)
          else
            case object
            when RDF::URI
              turtle.format_uri(object)
            else
              turtle.format_literal(object)
            end
          end
        end.join(", ")
        str
      end.join(";\n#{"  "*depth}")
      result << " ." if subject.iri?
      result << "\n"
      result << "#{"  "*(depth-1)}]" if not subject.iri?
      result
    end
    def format_turtle_inverse(object)
      turtle = RDF::Turtle::Writer.new
      result = ""
      @graph.query([nil, nil, object]).statements.sort_by do |e|
        [ e.subject, e.predicate, object ]
      end.map do |e|
        result << "<#{e.subject}> <#{e.predicate}> <#{object}>.\n"
      end
      result
    end

    def each_data
      @data.each do |uri, v|
        next if not uri.start_with? @config[:base_uri]
        yield uri, v
      end
    end
    def output_html_files
      each_data do |uri, v|
        template = Template.new("default.html.erb", @config)
        param = @config.dup
        param[:uri] = uri
        param[:data] = v
        param[:data_inverse] = @data_inverse[uri]
        param[:data_global] = @data
        param[:title] = template.get_title(v)
        if @data.keys.find{|e| e.start_with?(uri + "/") }
          file = uri + "/index.html"
        else
          file = uri + ".html"
        end
        #p uri, param
        file = file.sub(@config[:base_uri], "")
        if @config[:output_dir]
          Dir.mkdir @config[:output_dir] if not File.exist? @config[:output_dir]
          file = File.join(@config[:output_dir], file)
        end
        template.output_to(file, param)
      end
      index_html = "index.html"
      index_html = File.join(@config[:output_dir], "index.html") if @config[:output_dir]
      subjects = @graph.query([nil,
                              RDF::URI("http://www.w3.org/1999/02/22-rdf-syntax-ns#type"),
                              RDF::URI(@config[:top_class])]).subjects
      if @config.has_key? :top_class and subjects.size > 0
        template = Template.new("index.html.erb", @config)
        param = @config.dup
        param[:data_global] = @data
        subjects.each do |subject|
          param[:index_data] ||= []
          param[:index_data] << subject.to_s
        end
        template.output_to(index_html, param)
      end
      shapes = @graph.query([nil,
                             RDF::URI("http://www.w3.org/1999/02/22-rdf-syntax-ns#type"),
                             RDF::URI("http://www.w3.org/ns/shacl#NodeShape")])
      if shapes.size > 0
        about_html = "about.html"
        about_html =  File.join(@config[:output_dir], "about.html") if @config[:output_dir]
        template = Template.new("index.html.erb", @config)
        param = @config.dup
        param[:data_global] = @data
        param[:content] = {}
        shapes.subjects.each do |subject|
          param[:content][subject] = expand_shape(data, subject, prefix)
        end
        template.output_to(about_html, param)
      end
    end
    def output_turtle_files
      each_data do |uri, v|
        file = uri.sub(@config[:base_uri], "")
        file << ".ttl"
        if @config[:output_dir]
          Dir.mkdir @config[:output_dir] if not File.exist? @config[:output_dir]
          file = File.join(@config[:output_dir], file)
        end
        str = format_turtle(RDF::URI.new uri)
        str << format_turtle_inverse(RDF::URI.new uri)
        open(file, "w") do |io|
          io.puts str.strip
        end
      end
    end
    def cleanup
      @data.select do |uri, v|
        uri.start_with? @config[:base_uri]
      end.sort_by do |uri, v|
        -(uri.size)
      end.each do |uri, v|
        if @data.keys.find{|e| e.start_with?(uri + "/") }
          file = uri + "/index.html"
        else
          file = uri + ".html"
        end
        html_file = file.sub(@config[:base_uri], "")
        html_file = File.join(@config[:output_dir], html_file) if @config[:output_dir]
        File.unlink html_file
        ttl_file = uri.sub(@config[:base_uri], "") + ".ttl"
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
end
