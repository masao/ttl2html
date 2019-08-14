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
    end
    def output_to(file, param = {})
      @param = @param.update(param)
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
      @param = @param.update(param)
      template = File.join(File.dirname(__FILE__), "..", "..", template)
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
      if dest_uri.start_with? base_uri
        dest = dest_uri.sub(base_uri, "")
        relative_path(dest)
      else
        dest_uri
      end
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
      "no title"
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
      template = Template.new("templates/triples.html.erb", @param)
      template.to_html_raw("templates/triples.html.erb", data: triples)
    end
  end
end
