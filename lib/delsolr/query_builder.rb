require 'cgi'

module DelSolr

  class Client

    class QueryBuilder

      FL_DEFAULTS = 'id,unique_id,score' # redefine if you really want to change this.

      attr_accessor :query_name, :options

      # ops can basically be straight solr URL params, but it also supports some other formats
      # of different params to give it more of a "ruby" feel (ie: :filters can be an array, hash, or string, 
      # but you can also just specify the fq params directly
      def initialize(query_name, opts = {})
        @query_name = query_name
        @options = opts
      end

      def request_string
        @request_string ||= build_request_string
      end

      private

      def build_request_string()
        raise "query_name must be set" if query_name.blank?

        opts = self.options.dup

        # cleanup the nils
        opts.delete_if {|k,v| v.nil?}

        # resolve "rubyish" names to solr names
        opts[:q] ||= opts[:query]
        opts[:rows] ||= opts[:limit] || 10
        opts[:start] ||= opts[:offset] || 0
        opts[:start] = 0 if opts[:start].to_i < 0
        opts[:fl] ||= opts[:fields] || FL_DEFAULTS
        opts[:bq] ||= opts[:boost]
        opts[:suggestionCount] ||= opts[:suggestion_count]
        opts[:onlyMorePopular] ||= opts[:only_more_popular]

        raise ":query or :q must be set" if opts[:q].nil? || opts[:q].empty?

        # clear out the "rubyish" versions, what's left will go straight to solr
        opts.delete(:query)
        opts.delete(:limit)
        opts.delete(:offset)
        opts.delete(:fields)
        opts.delete(:boost)
        opts.delete(:suggestion_count)
        opts.delete(:only_more_popular)

        # needs to be an array of hashs because it's acceptable to have the same key present > once.
        params = []

        # remove params as we go so we can just pass whatever is left to solr...

        params << build_query(:q, opts.delete(:q))
        params << {:wt => 'ruby'}
        params << {:qt => query_name}
        params << {:rows => opts.delete(:rows)}
        params << {:start => opts.delete(:start)}
        params << {:fl => opts.delete(:fl)}

        filters = opts.delete(:filters)
        params += build_filters(:fq, filters)
        params += build_filters(:bq, opts.delete(:bq))

        facets = opts.delete(:facets)
        if facets
          if facets.is_a?(Array)
            params << {:facet => true}
            params += build_facets(facets)          
          elsif facets.is_a?(Hash)
            params << {:facet => true}
            params += build_facet(facets)
          elsif facets.is_a?(String)
            params += facets
          else
            raise 'facets must either be a Hash or an Array'
          end
        end

        # handle friendly highlight name
        if opts.delete(:highlight)
          params << {:hl => 'true'}
          params << {'hl.fl' => opts['hl.fl'] || opts[:fl] }
        end

        # just pass everything that's left to solr
        opts.each { |k,v| params << {k => v} if !v.nil? }

        # convert the params (array of hashes)
        param_strings = params.collect do |h|
          if h.is_a?(Hash)
            ha = h.to_a
            "#{ha[0][0]}=#{::CGI::escape(ha[0][1].to_s)}"
          elsif h.is_a?(String)
            h # just return the string
          else
            raise "All params should be a Hash or String"
          end
        end

        "/select?#{param_strings.join('&')}"
      end

      # returns the query param
      def build_query(key, queries, localparams = "")
        query_string = ''
        case queries
        when String
          query_string = queries
        when Array
          query_string = queries.join(' ')
        when Hash
          query_string_array = []
          queries.each do |k,v|
            query_string_array << key_value_pair_string(k, v)
          end
          query_string = query_string_array.join(' ')
        end

        query_string = localparams + query_string

        {key => query_string}
      end

      def key_value_pair_string(k, v)
        str = ''
        if v.is_a?(Array) # add a filter for each value
          str_ary = []
          v.each do |val|
            str_ary << key_value_pair_string(k, val)
          end
          str = str_ary.join(' ')
        elsif v.is_a?(Range)
          str = "#{k}:[#{v.begin} TO #{v.end}]"
        elsif v.is_a?(String)
          if v =~ /\s/ && # if it contains a space, we may need to quote it
            !(v =~ /^\[.+ TO .+\]$/) # HACK: if the string is a range query, do not wrap it in quotes
            str = "#{k}:\"#{v}\""
          else
            str = "#{k}:#{v}"
          end
        else
          str = "#{k}:#{v}"
        end
        str
      end

      def build_filters(key, filters)
        params = []

        # handle "ruby-ish" filters
        case filters
        when String
          params << {key => filters}
        when Array
          filters.each do |f|
            params += build_filters(key, f) # recusively add all the filters in the array
          end
        when Hash
          filters_local_params = build_local_params(filters['localparams'] || filters[:localparams])
          filters.each do |k,v|
            next if ['localparams', :localparams].include?(k.to_s)
            params << {key => filters_local_params + key_value_pair_string(k, v)} unless v.nil?
          end
        end
        params
      end

      def build_facets(facet_array)
        params = []
        facet_array.each do |facet_hash|
          params += build_facet(facet_hash)
        end
        params
      end

      def build_facet(facet_hash)
        params = []
        facet_name = facet_hash['name'] || facet_hash[:name]
        unless facet_name.blank?
          facet_hash[:localparams] ||= {}
          facet_hash[:localparams][:key] ||= facet_name
        end
        facet_local_params = build_local_params(facet_hash['localparams'] || facet_hash[:localparams])
        facet_hash.each do |k,v|
          # handle some cases specially
          if 'field' == k.to_s
            params << {"facet.field" => "#{facet_local_params}#{v}"}
          elsif 'query' == k.to_s
            params << build_query("facet.query", v, facet_local_params)
          elsif ['localparams', :localparams, 'name', :name].include?(k.to_s)
            # do nothing
          else
            params << {"f.#{facet_hash[:field]}.facet.#{k}" => "#{v}"}
          end
        end
        params
      end

      def build_local_params_array(local_params)
        local_params_array = []
        case local_params
        when String
          local_params_array << local_params
        when Array
          local_params.each do |p|
            local_params_array << build_local_params_array(p)
          end
        when Hash
          local_params.each do |k,v|
            local_params_array << "#{k}=#{v}"
          end
        end
        local_params_array
      end

      def build_local_params(local_params)
        local_params_array = build_local_params_array(local_params)

        local_params_array.empty? ? "" : "{!#{local_params_array.join(" ")}}"
      end

    end
  end
end
