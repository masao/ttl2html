#!/usr/bin/env ruby

require "yaml"
require "nokogiri"
require "rdf/turtle"
require "ruby-progressbar"

require "ttl2html/pagetemplate"

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
            i@graph.query([object, nil, nil]).statements.sort_by{|e|
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

    def each_data
      if @config[:output_dir]
        Dir.mkdir @config[:output_dir] if not File.exist? @config[:output_dir]
        Dir.chdir @config[:output_dir]
      end
      @data.each do |uri, v|
        next if not uri.start_with? @config[:base_uri]
        yield uri, v
      end
    end
    def output_html_files
      each_data do |uri, v|
        template = PageTemplate.new("templates/default.html.erb")
        param = @config.dup
        param[:uri] = uri
        param[:data] = v
        param[:data_global] = @data
        param[:title] = template.get_title(v)
        if @data.keys.find{|e| e.start_with?(uri + "/") }
          file = uri + "/index.html"
        else
          file = uri + ".html"
        end
        #p uri, param
        file = file.sub(@config[:base_uri], "")
        #STDERR.puts "output_to #{file}"
        template.output_to(file, param)
      end
    end
    def output_turtle_files
      each_data do |uri, v|
        file = uri.sub(@config[:base_uri], "")
        file << ".ttl"
        str = format_turtle(RDF::URI.new uri)
        open(file, "w") do |io|
          io.puts str.strip
        end
      end
    end
    def cleanup
      each_data do |uri, v|
        if @data.keys.find{|e| e.start_with?(uri + "/") }
          file = uri + "/index.html"
        else
          file = uri + ".html"
        end
        html_file = file.sub(@config[:base_uri], "")
        File.unlink html_file
        ttl_file = uri.sub(@config[:base_uri], "") + ".ttl"
        File.unlink ttl_file
      end
    end
  end
end
