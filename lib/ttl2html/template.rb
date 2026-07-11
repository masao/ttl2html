#!/usr/bin/env ruby

require "fileutils"
require "pathname"
require "erb"
require "i18n"
require "action_view"
require "nokogiri"

module TTL2HTML
  class Template
    include ERB::Util
    include I18n::Base
    include ActionView::Helpers::NumberHelper
    def initialize(template, param = {})
      @template = template
      @param = param.dup
      @template_path = [ File.join(Dir.pwd, "templates") ]
      @template_path << File.join(File.dirname(__FILE__), "..", "..", "templates")
      I18n.load_path << Dir[File.join(File.dirname(__FILE__), "..", "..", "locales") + "/*.yml"]
      I18n.load_path << Dir[File.expand_path("locales") + "/*.yml"]
      I18n.locale = @param[:locale].to_sym if @param[:locale]
    end
    def output_to(file, param = {})
      param = @param.merge(param)
      param[:output_file] = file
      FileUtils.mkdir_p(File.dirname(file))
      File.open(file, "w") do |io|
        io.print to_html(param)
      end
    end
    def to_html(param)
      param[:content] = to_html_raw(@template, param)
      layout_fname = "layout.html.erb"
      to_html_raw(layout_fname, param)
    end
    def to_html_raw(template, param)
      param = @param.merge(param)
      template = find_template_path(template)
      tmpl = File.open(template) { |io| io.read }
      erb = ERB.new(tmpl, trim_mode: "-")
      erb.filename = template
      I18n.with_locale(@param[:locale] || I18n.default_locale) do
        erb.result(binding)
      end
    end

    def find_template_path(fname)
      if @param[:template_dir] and Dir.exist?(@param[:template_dir])
        @template_path.unshift(@param[:template_dir])
        @template_path.uniq!
      end
      @template_path.each do |dir|
        file = File.join(dir, fname)
        return file if File.file? file
      end
      nil
    end

    def expand_shape(data, uri, prefixes = {}, depth = 0)
      return nil if not data[uri]
      return nil if not data[uri]["http://www.w3.org/ns/shacl#property"]
      return nil if depth > 10
      prefix_used = {}
      result = data[uri]["http://www.w3.org/ns/shacl#property"].sort_by do |e|
        e["http://www.w3.org/ns/shacl#order"]
      end.map do |property|
        path = data[property]["http://www.w3.org/ns/shacl#path"].first
        shorten_path = path.dup
        prefixes.each do |prefix, val|
          if path.index(val) == 0
            shorten_path = path.sub(/\A#{val}/, "#{prefix}:")
            prefix_used[prefix] = val
          end
        end
        repeatable = false
        if data[property]["http://www.w3.org/ns/shacl#maxCount"]
          max_count = data[property]["http://www.w3.org/ns/shacl#maxCount"].first.to_i
          if max_count > 1
            repeatable = true
          end
        else
          repeatable = true
        end
        nodes = nil
        if data[property]["http://www.w3.org/ns/shacl#node"]
          node = data[property]["http://www.w3.org/ns/shacl#node"].first
          if data[node]["http://www.w3.org/ns/shacl#or"]
            node_or = data[data[node]["http://www.w3.org/ns/shacl#or"].first]
            node_mode = :or
            nodes = []
            nodes << expand_shape(data, node_or["http://www.w3.org/1999/02/22-rdf-syntax-ns#first"].first, prefixes, depth + 1)
            rest = node_or["http://www.w3.org/1999/02/22-rdf-syntax-ns#rest"].first
            while data[rest] do
              nodes << expand_shape(data, data[rest]["http://www.w3.org/1999/02/22-rdf-syntax-ns#first"].first, prefixes, depth + 1)
              rest = data[rest]["http://www.w3.org/1999/02/22-rdf-syntax-ns#rest"].first
            end
          else
            nodes = expand_shape(data, node, prefixes, depth + 1)
          end
          #p nodes
        end
        example = data[property]["http://www.w3.org/2004/02/skos/core#example"].first if data[property]["http://www.w3.org/2004/02/skos/core#example"]
        if example.respond_to?(:datatype) and example.datatype?
          datatype = example.datatype.pname or example.datatype.to_s
          example = example.to_s + "<span class=\"datatype\">^^" + example.datatype.pname + "</span>"
        end
        descriptions = [ get_language_literal(data[property]["http://www.w3.org/ns/shacl#description"]) ]
        if data[property]["http://www.w3.org/ns/shacl#datatype"]
          datatypes = data[property]["http://www.w3.org/ns/shacl#datatype"].map do |datatype|
            datatype.to_s.sub(%r{\Ahttp://www\.w3\.org/2001/XMLSchema#}, 'xsd:')
          end.join(", ")
          descriptions << t('shape-table.datatype') + datatypes
        end
        {
          path: path,
          shorten_path: shorten_path,
          name: get_language_literal(data[property]["http://www.w3.org/ns/shacl#name"]),
          example: example,
          description: descriptions.compact.join("<br>"),
          required: data[property]["http://www.w3.org/ns/shacl#minCount"] ? data[property]["http://www.w3.org/ns/shacl#minCount"].first.to_i > 0 : false,
          repeatable: repeatable,
          nodeKind: data[property]["http://www.w3.org/ns/shacl#nodeKind"] ? data[property]["http://www.w3.org/ns/shacl#nodeKind"].first : nil,
          class: data[property]["http://www.w3.org/ns/shacl#class"] ? data[property]["http://www.w3.org/ns/shacl#class"].first : nil,
          nodes: nodes,
          node_mode: node_mode,
          prefix: prefix_used,
        }
      end
      template = "shape-table.html.erb"
      to_html_raw(template, { properties: result, prefix: prefix_used })
    end

    # helper method:
    include TTL2HTML::Util
    def relative_path(src, dest)
      path = nil
      dest_uri = RDF::IRI.parse(dest)
      if dest_uri.absolute?
        path = dest
      else
        dest.sub!(/^\/+/, "")
        #p [:relative_path, src, dest]
        # src is always passed as an absolute path.
        base_dir = Pathname.pwd
        base_dir = Pathname.new(@param[:output_dir]).expand_path if @param[:output_dir]
        # src is always passed as an absolute path, but normalize it to remove
        # any "." or ".." components before calling relative_path_from.
        src_path = Pathname.new(src).expand_path
        src_relative = src_path.relative_path_from(base_dir)
        path = Pathname.new(dest).relative_path_from(src_relative.dirname)
        path = "#{path}/" if base_dir.join(dest).cleanpath.directory?
      end
      #p [ :relative_path, path, dest, src ]
      path
    end
    def relative_path_uri(src, dest_uri, base_uri = @param[:base_uri])
      # A relative link cannot be calculated without the source output file.
      # Fall back to the original absolute URI.
      return dest_uri unless src
      if dest_uri.start_with? base_uri
        dest = dest_uri.sub(base_uri, "")
        dest = uri_mapping_to_path(dest, @param, "")
        relative_path(src, dest)
      else
        dest_uri
      end
    end
    def html_title(param)
      titles = []
      if @template.start_with? "about.html"
        titles << t("about.title", title: param[:site_title])
      else
        titles << param[:title]
        titles << param[:site_title]
      end
      titles.compact.join(" - ")
    end
    def shorten_title(title, length = 140)
      if title.to_s.length > length
        short_title = Nokogiri::HTML::DocumentFragment.parse(title.to_s[0..length])
        short_title.to_html + "..."
      else
        ERB::Util.html_escape title
      end
    end
    def get_title(data, default_title = "no title")
      resolve_title(data,
        default: default_title,
        use_default: true,
        property_key: :title_property,
        perclass_key: :title_property_perclass
      )
    end
    def get_subtitle(data, default_title = nil)
      resolve_title(data,
        default: default_title,
        use_default: false,
        property_key: :subtitle_property,
        perclass_key: :subtitle_property_perclass
      )
    end
    def get_language_literal(object)
      if object.is_a? Array
        object_lang = object.select do |e|
          e.language? and e.language == I18n.locale
        end
        if not object_lang.empty?
          object_lang.first
        else
          object.first
        end
      else
        object
      end
    end
    def format_property(property, param, subject = nil)
      param = @param.merge(param)
      subject = param[:blank_subject] if not subject and param[:blank_subject]
      subject_class = param[:data_global][subject][RDF.type.to_s]&.first if subject
      if subject_class and param[:labels_with_class][subject_class] and param[:labels_with_class][subject_class][property]
        param[:labels_with_class][subject_class][property]
      elsif param[:labels] and param[:labels][property]
        param[:labels][property]
      else
        property.split(/[\/\#]/).last.capitalize
      end
    end
    def format_object(object, param)
      type = param[:type] || {}
      data = param[:data] || {}
      if /\Ahttps?:\/\// =~ object.to_s
        #p [:format_object_uri, param[:output_file], object]
        rel_path = relative_path_uri(param[:output_file], object)
        if param[:data_global][object]
          result = "<a href=\"#{rel_path}\">#{get_title(param[:data_global][object]) or ERB::Util.html_escape(object)}</a>"
          subtitle = get_subtitle(param[:data_global][object])
          if subtitle
            result += " <small>#{subtitle}</small>"
          else
            result
          end
        else
          "<a href=\"#{rel_path}\">#{ERB::Util.html_escape object}</a>"
        end
      elsif /\A_:/ =~ object.to_s and param[:data_global][object]
        if type[:inverse] and param[:data_inverse_global][object]
          format_triples(param[:data_inverse_global][object], param, inverse: true, blank: true)
        else
          format_triples(param[:data_global][object], param, blank: true)
        end
      else
        ERB::Util.html_escape object
      end
    end
    def format_triples(triples, param, type = {})
      param_local = @param.dup.merge(param)
      param_local = param_local.merge(data: triples)
      param_local[:type] = type
      if @param[:labels_with_class] and triples["http://www.w3.org/1999/02/22-rdf-syntax-ns#type"]
        @param[:labels_with_class].reverse_each do |k, v|
          triples["http://www.w3.org/1999/02/22-rdf-syntax-ns#type"].each do |entity_class|
            if entity_class == k
              v.each do |property, label_value|
                param_local[:labels] ||= {}
                param_local[:labels][property] = label_value
              end
            end
          end
        end
      end
      if @param[:orders_with_class] and triples["http://www.w3.org/1999/02/22-rdf-syntax-ns#type"]
        @param[:orders_with_class].reverse_each do |k, v|
          triples["http://www.w3.org/1999/02/22-rdf-syntax-ns#type"].each do |entity_class|
            if entity_class == k
              v.each do |property, order|
                param_local[:orders] ||= {}
                param_local[:orders][property] = order || Float::INFINITY
              end
            end
          end
        end
      end
      if type[:inverse] == true
        if type[:blank] == true
          #p param_local[:data]
          #p param_local[:data_inverse]
          #p param_local[:data_inverse].values.first.first
          param_local[:blank_subject] = param_local[:data].values.first.first
          param_local[:blank_triples] = {
            param_local[:data].keys.first => param_local[:data_global][param_local[:blank_subject]][param_local[:data].keys.first]
          }
          #p param_local[:blank_subject]
          #p param_local[:blank_triples]
          param_local[:type] = {}
          #pp param_local
          to_html_raw("triples-blank.html.erb", param_local)
        else
          to_html_raw("triples-inverse.html.erb", param_local)
        end
      else
        to_html_raw("triples.html.erb", param_local)
      end
    end
    def format_version_info(version)
      param_local = @param.dup.merge(data: version)
      to_html_raw("version.html.erb", param_local)
    end

    private

    def resolve_title(data, default:, use_default:, property_key:, perclass_key:)
      return default if data.nil?
      # rdf:type
      type_key = "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
      # 1. クラスごとのプロパティ指定がある場合
      if @param[perclass_key].is_a?(Hash) && data[type_key]
        Array(data[type_key]).each do |klass|
          if @param[perclass_key][klass]
            prop = @param[perclass_key][klass]
            if valid_value?(data[prop])
              return shorten_title(get_language_literal(data[prop]))
            end
          end
        end
      end
      # 2. 一般プロパティ
      if @param[property_key] && valid_value?(data[@param[property_key]])
        return shorten_title(get_language_literal(data[@param[property_key]]))
      end
      # 3. デフォルト候補を順にチェック
      if use_default
        [
          "http://www.w3.org/2000/01/rdf-schema#label",
          "http://purl.org/dc/terms/title",
          "http://purl.org/dc/elements/1.1/title",
          "https://schema.org/name",
          "http://schema.org/name",
          "http://www.w3.org/2004/02/skos/core#prefLabel"
        ].each do |prop|
          return shorten_title(get_language_literal(data[prop])) if valid_value?(data[prop])
        end
      end
      # 4. fallback
      default
    end
    def valid_value?(value)
      value && !(value.respond_to?(:empty?) && value.empty?)
    end
    def sort_criteria(val, data_global)
      raise "sort_criteria got nil." if data_global.nil?
      resource = data_global[val]
      results = []
      [
         "http://purl.org/linked-data/cube#order",
         "https://schema.org/position",
         "http://schema.org/position",
      ].each do |order_elem|
        if resource and resource[order_elem]
          order_val = resource[order_elem].first.to_s
          if data_global[order_val] and data_global[order_val][RDF::RDFV::value.to_s]
            results << data_global[order_val][RDF::RDFV::value.to_s].first.to_i
          else
            results << order_val.to_i
          end
        else
          results << Float::INFINITY
        end
      end
      if val.to_s =~ /^_:/
        results << resource.to_s
      else
        results << val.to_s
      end
      #p [val, results]
      results
    end
  end
end
