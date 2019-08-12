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
  def initialize
    @template = {}
    @config = load_config
    if not @config[:base_uri]
      raise "load_config: base_uri not found"
    end
    @data = {}
  end

  def load_config(file = "config.yml")
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

  def output_html_files
    using ProgressBar::Refinements::Enumerator
    @data.each do |uri, v|
      next if not uri.start_with? @config[:base_uri]
      template = PageTemplate.new("templates/default.html.erb")
      param = @config.dup
      param[:uri] = uri
      param[:data] = v
      param[:data_global] = @data
      param[:title] = template.get_title(v)
      #p uri, param
      file = uri.sub(@config[:base_uri], "")
      STDERR.puts "output_to #{file}"
      template.output_to(file, param)
    end
  end
end

if $0 == __FILE__
  ttl2html = TTL2HTML.new
  ARGV.each do |file|
    ttl2html.load_turtle(file)
  end
  ttl2html.output_html_files
end
