#!/usr/bin/env ruby

require "roo"

module XLSX2Shape
  def xlsx2shape(filename)
    shapes = {}
    prefix = { sh: "http://www.w3.org/ns/shacl#" }
    xlsx = Roo::Excelx.new(filename)
    xlsx.each_with_pagename do |name, sheet|
      if name =~ /\Aprefix\z/i
        sheet.each do |row|
          prefix[row[0].to_s.intern] = row[1] if not row[1].empty?
        end
      else
        headers = sheet.row(1)
        uri = headers.first
        shapes[uri] = ["<#{uri}> a sh:NodeShape"]
        order = 1
        sheet.each_with_index do |row, idx|
          row_h = map_xlsx_row_headers(row, headers)
          case row.first
          when "sh:targetClass"
            shapes[uri] << "#{format_property("sh:targetClass", row[1])}" if row[1]
          when "sh:property"
            prop_values = []
            headers[1..-1].each do |prop|
              next if row_h[prop].empty?
              case prop
              when /\@(\w+)\z/
                lang = $1
                property_name = prop.sub(/\@(\w+)\z/, "")
                prop_values << format_property(property_name, row_h[prop], lang)
              when "sh:minCount", "sh:maxCount"
                prop_values << format_property(prop, row_h[prop].to_i)
              when "sh:languageIn"
                prop_values << "  sh:languageIn (#{row_h[prop].split.map{|e| format_pvalue(e) }.join(" ")})"
              when "sh:uniqueLang"
                case row_h[prop]
                when "true"
                  prop_values << "  sh:uniqueLang true"
                when "false"
                  prop_values << "  sh:uniqueLang false"
                else
                  logger.warn "sh:uniqueLang value unknown: #{row_h[prop]} at #{uri}"
                end
              else
                prop_values << format_property(prop, row_h[prop])
              end
            end
            prop_values << format_property("sh:order", order)
            order += 1
            str = prop_values.join(";\n  ")
            shapes[uri] << "  sh:property [\n  #{str}\n  ]"
          when "sh:or"
            shapes[uri] << "  sh:or (#{row[1..-1].select{|e| not e.empty? }.map{|e| format_pvalue(e) }.join(" ")})"
          end
        end
      end
    end
    result = ""
    prefix.sort_by{|k,v| [k,v] }.each do |prefix, val|
      result << "@prefix #{prefix}: <#{val}>.\n"
    end
    shapes.sort_by{|uri, val| uri }.each do |uri, val|
      result << "\n"
      result << shapes[uri].join(";\n")
      result << ".\n"
    end
    result
  end

  def map_xlsx_row_headers(data_row, headers)
    hash = {}
    headers.each_with_index do |h, idx|
      hash[h] = data_row[idx].to_s
    end
    hash
  end
  def format_pvalue(value, lang = nil)
    str = ""
    if value.is_a? Hash
      result = ["["]
      array = []
      value.keys.sort.each do |k|
        array << format_property(k, value[k])
      end
      result << array.join(";\n")
      result << "  ]"
      str = result.join("\n")
    elsif value.is_a? Integer
      str = value
    elsif value =~ /\Ahttps?:\/\//
      str = %Q|<#{value}>|
    elsif value =~ /\A\w+:[\w\-\.]+\Z/
      str = value
    elsif value =~ /\A(.+?)\^\^(\w+:\w+)\z/
      str = %Q|"#{escape_turtle($1)}"^^#{$2}|
    elsif lang
      str = %Q|"#{escape_turtle(value)}"@#{lang}|
    else
      str = %Q|"#{escape_turtle(value)}"|
    end
    str
  end
  def format_property(property, value, lang = nil)
    if value.is_a? Array
      value = value.sort_by{|e|
        format_pvalue(e)
      }.map do |e|
        format_pvalue(e)
      end
      %Q|  #{property} #{ value.join(", ") }|
    else
      value = format_pvalue(value, lang)
      %Q|  #{property} #{value}|
    end
  end
  def escape_turtle(str)
    str.gsub(/\\/){ '\\\\' }.gsub(/"/){ '\"' }
  end
end
