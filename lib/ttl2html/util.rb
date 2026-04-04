module TTL2HTML
  module Util
    def make_mapping_uris_cache(param)
      @path_cache = Set.new
      data = @data || @param[:data_global] || @param[:data] || {}

      data.keys.each do |uri|
        local_path = _uri_mapping_to_path(uri, param)
        # 親パスをすべて抽出してSetに追加
        idx = 0
        while (idx = local_path.index("/", idx))
          parent = local_path[0...idx]
          @path_cache << parent unless parent.empty?
          idx += 1
        end
      end
      @path_cache
    end
    def _uri_mapping_to_path(uri, param, suffix = ".html")
      local_path = uri.sub(param[:base_uri], "")
      if param[:uri_mappings]
        param[:uri_mappings].each do |mapping|
          if mapping["regexp"] =~ local_path
            #p [mapping["regexp"], local_path]
            local_path = local_path.sub(mapping["regexp"], mapping["path"])
            #p [mapping["regexp"], local_path]
          end
        end
      end
      local_path
    end
    def uri_mapping_to_path(uri, param, suffix = ".html")
      path = nil
      @path_cache ||= make_mapping_uris_cache(param)
      path = _uri_mapping_to_path(uri, param, suffix)
      if suffix == ".html"
        if @path_cache.include? path
          path += "/index"
        elsif path.end_with?("/")
          path += "index"
        end
      end
      path << suffix
      #p [uri, path]
      path
    end  
  end
end