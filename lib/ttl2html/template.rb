#!/usr/bin/env ruby

require "fileutils"
require "pathname"
require "erb"

module TTL2HTML
  class Template
    attr_reader :param
    include ERB::Util
    def initialize(template, param = {})
      @template = template
      @param = param
      @template_path = [ Dir.pwd, File.join(Dir.pwd, "templates") ]
      @template_path << File.join(File.dirname(__FILE__), "..", "..", "templates")
    end
    def output_to(file, param = {})
      @param.update(param)
      @param[:output_file] = file
      dir = File.dirname(file)
      FileUtils.mkdir_p(dir) if not File.exist?(dir)
      open(file, "w") do |io|
        io.print to_html(@param)
      end
    end
    def to_html(param)
      param[:content] = to_html_raw(@template, param)
      layout_fname = "layout.html.erb"
      to_html_raw(layout_fname, param)
    end
    def to_html_raw(template, param)
      @param.update(param)
      template = find_template_path(template)
      tmpl = open(template){|io| io.read }
      erb = ERB.new(tmpl, nil, "-")
      erb.filename = template
      erb.result(binding)
    end

    def find_template_path(fname)
      if @param[:template_dir] and Dir.exist?(@param[:template_dir])
        @template_path.unshift(@param[:template_dir])
        @template_path.uniq!
      end
      @template_path.each do |dir|
        file = File.join(dir, fname)
        return file if File.exist? file
      end
      return nil
    end
  
    # helper method:
    def relative_path(dest)
      src = @param[:output_file]
      src = Pathname.new(src).relative_path_from(Pathname.new(@param[:output_dir])) if @param[:output_dir]
      path = Pathname(dest).relative_path_from(Pathname(File.dirname src))
      path = path.to_s + "/" if File.directory? path
      path
    end
    def relative_path_uri(dest_uri, base_uri)
      if dest_uri.start_with? base_uri
        dest = dest_uri.sub(base_uri, "")
        relative_path(dest)
      else
        dest_uri
      end
    end
    def get_title(data)
      if @param[:title_property] and data[@param[:title_property]]
        return get_language_literal(data[@param[:title_property]])
      end
      %w(
        https://www.w3.org/TR/rdf-schema/#label
        http://purl.org/dc/terms/title
        http://purl.org/dc/elements/1.1/title
        http://schema.org/name
        http://www.w3.org/2004/02/skos/core#prefLabel
      ).each do |property|
        return get_language_literal(data[property]) if data[property]
      end
      "no title"
    end
    def get_language_literal(object)
      if object.respond_to? :has_key?
        object.values.first
      elsif object.is_a? Array
        object.first
      else
        object
      end
    end
    def format_property(property, labels = {})
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
      param_local = @param.merge(data: triples)
      to_html_raw("triples.html.erb", param_local)
    end
  end
end
