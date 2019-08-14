#!/usr/bin/env ruby

require "fileutils"
require "pathname"
require "yaml"
require "erb"
require "nokogiri"
require "rdf/turtle"
require "ruby-progressbar"

#require_relative "util.rb"

class PageTemplate
  attr_reader :param
  include ERB::Util
  def initialize(template)
    @template = template
    @param = {}
  end
  def output_to(file, param)
    @param = param
    @param[:output_file] = file
    dir = File.dirname(file)
    FileUtils.mkdir_p(dir) if not File.exist?(dir)
    open(file, "w") do |io|
      io.print to_html(@param)
    end
  end
  def to_html(param)
    param[:content] = to_html_raw(@template, param)
    layout_fname = "templates/layout.html.erb"
    to_html_raw(layout_fname, param)
  end
  def to_html_raw(template, param)
    @param = @param.merge(param)
    template = File.join(File.dirname(__FILE__), template)
    tmpl = open(template){|io| io.read }
    erb = ERB.new(tmpl, $SAFE, "-")
    erb.filename = template
    erb.result(binding)
  end

  # helper method:
  def relative_path(dest)
    src = @param[:output_file]
    path = Pathname(dest).relative_path_from(Pathname(File.dirname src))
    path = path.to_s + "/" if File.directory? path
    path
  end
  def relative_path_uri(dest_uri, base_uri)
    dest = dest_uri.sub(base_uri, "")
    relative_path(dest)
  end
  def get_title(data)
    %w(
      https://www.w3.org/TR/rdf-schema/#label
      http://purl.org/dc/terms/title
      http://purl.org/dc/elements/1.1/title
      http://schema.org/name
      http://www.w3.org/2004/02/skos/core#prefLabel
    ).each do |property|
      return data[property].first if data[property]
    end
  end
  def format_property(property, labels)
    if labels and labels[property]
      labels[property]
    else
      property.split(/[\/\#]/).last.capitalize
    end
  end
  def format_object(object, data)
    if object =~ /\Ahttps?:\/\//
      rel_path = relative_path_uri(object, param[:base_uri])
      if data[object]
        "<a href=\"#{rel_path}\">#{get_title(param[:data_global][object]) or object}</a>"
      else
        "<a href=\"#{rel_path}\">#{object}</a>"
      end
    elsif object =~ /\A_:/ and param[:data_global][object]
      format_triples(param[:data_global][object])
    else
      object
    end
  end
  def format_triples(triples)
    template = PageTemplate.new("templates/triples.html.erb")
    template.to_html_raw("templates/triples.html.erb", param.update({data: triples}))
  end
end

class TTL2HTML
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

if $0 == __FILE__
  require "getoptlong"
  parser = GetoptLong.new
  parser.set_options(
    ['--cleanup', GetoptLong::NO_ARGUMENT],
    ['--config',  GetoptLong::REQUIRED_ARGUMENT],
  )
  opt_cleanup = false
  opt_config = "config.yml"
  parser.each_option do |optname, optarg|
    if optname == "--cleanup"
      opt_cleanup = true
    elsif optname == "--config"
      opt_config = optarg
    end
  end
  ttl2html = TTL2HTML.new(opt_config)
  ARGV.each do |file|
    ttl2html.load_turtle(file)
  end
  if opt_cleanup
    ttl2html.cleanup
  else
    ttl2html.output_html_files
    ttl2html.output_turtle_files
  end
end
