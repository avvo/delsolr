require 'json'

module DelSolr
  class Client
    class Response

      attr_reader :query_builder

      def initialize(solr_response_buffer, query_builder, options = {})
        @query_builder = query_builder
        @from_cache = options[:from_cache]
        @logger = options[:logger]
        begin
          @raw_response = JSON.parse(solr_response_buffer)
        rescue JSON::ParserError => e
          if @logger
            @logger.error(solr_response_buffer)
            @logger.error(e)
          end
          raise e
        end

        # now define the shortcuts
        options[:shortcuts] ||= [:id, :unique_id, :score]
        options[:shortcuts].each do |shortcut|
          instance_eval %{
            def #{shortcut}s
              @#{shortcut}s ||= docs.collect {|d| d['#{shortcut}'] }
            end
          }
        end
      end

      # Rreturns the "raw" ruby hash that is returned by the solr ruby response writer.  This is mostly for debugging purposes
      def raw_response
        @raw_response
      end

      # Did we get some kind of valid response back from solr?
      def success?
        !raw_response.nil?
      end
      
      # Returns the total number of matches
      def total
        @total ||= raw_response['response']['numFound']
      end
      
      # Returns true if there no results
      def blank?
        raw_response.blank? || total < 1
      end
      
      alias_method :empty?, :blank?
      
      # Returns true if this response was pulled from the cache
      def from_cache?
        @from_cache
      end
      
      # Returns the offset that was given in the request
      def offset
        @offset ||= raw_response['response']['start']
      end

      # Returns the max score of the result set
      def max_score
        @max_score ||= raw_response['response']['maxScore'].to_f
      end

      # Returns an array of all the docs
      def docs
        @docs ||= raw_response['response']['docs']
      end
      
      # Helper for displaying a given field (first tries the highlight, then the stored value)
      def display_for(doc, field)
        highlights_for(doc['unique_id'], field) || doc[field]
      end
      
      # Returns the highlights for a given id for a given field
      def highlights_for(unique_id, field)
        raw_response['highlighting'] ||= {}
        raw_response['highlighting'][unique_id] ||= {}
        raw_response['highlighting'][unique_id][field]
      end

      def suggestions
        @suggestions ||= raw_response['spellcheck']['suggestions'] if raw_response && raw_response['spellcheck']
      end

      # solr is super-weird about the way it returns suggestions,
      # hence this strangeness:
      # 'spellcheck'=>{'suggestions'=>['fishh',{'numFound'=>1,'startOffset'=>0,'endOffset'=>4,'suggestion'=>['fish']},'collation','fish']}
      def collation_with_correction
        @collation_with_correction ||= begin
          collation, correction = nil, {}
          if suggestions
            (suggestions.length/2).times do |i|
              k = suggestions[i*2]
              v = suggestions[i*2+1]
              collation = v if k == 'collation'
              correction[k] = v['suggestion'][0] if v.is_a?(Hash)
            end
          end
          {'collation' => collation, 'correction' => correction}
        end
      end

      def correction
        collation_with_correction['correction']
      end

      def collation
        collation_with_correction['collation']
      end
      
      # Returns the query time in ms
      def qtime
        @qtime ||= raw_response['responseHeader']['QTime'].to_i
      end

      # Returns the status code (0 for success)
      def status
        @status ||= raw_response['responseHeader']['status']
      end

      # Returns the params hash
      def params
        @params ||= raw_response['responseHeader']['params']
      end
      
      # Returns the entire facet hash
      def facets
        @facets ||= raw_response['facet_counts'] || {}
      end
      
      # Returns the hash of all the facet_fields (ie: {'instock_b' => ['true', 123, 'false', 20]}
      def facet_fields
        @facet_fields ||= facets['facet_fields'] || {}
      end
      
      # Returns all of the facet queries
      def facet_queries
        @facet_queries ||= facets['facet_queries'] || {}
      end
      
      # Returns a hash of hashs rather than a hash of arrays (ie: {'instock_b' => {'true' => 123', 'false', => 20} })
      def facet_fields_by_hash
        @facet_fields_by_hash ||= begin
          f = {}
          if facet_fields
            facet_fields.each do |field,value_and_counts|
              f[field] = {}
              value_and_counts.each_with_index do |v, i|              
                if i % 2 == 0
                  f[field][v] = value_and_counts[i+1]
                end
              end
            end
          end
          f
        end
      end
      
      # Returns an array of value/counts for a given field (ie: ['true', 123, 'false', 20]
      def facet_field(field)
        facet_fields[field.to_s] || []
      end
      
      # Returns the array of field values for the given field in the order they were returned from solr
      def facet_field_values(field)
        facet_field_values ||= {}
        facet_field_values[field.to_s] ||= begin
          a = []
          facet_field(field).each_with_index do |val_or_count, i|
            a << val_or_count if i % 2 == 0 && facet_field(field)[i+1] > 0
          end
          a
        end
      end
      
      # Returns a hash of value/counts for a given field (ie: {'true' => 123, 'false' => 20}
      def facet_field_by_hash(field)
        facet_fields_by_hash[field.to_s]
      end
      
      # Returns the count for the given field/value pair
      def facet_field_count(field, value)
        facet_fields_by_hash[field.to_s][value.to_s] if facet_fields_by_hash[field.to_s]
      end
      
      # Returns the counts for a given facet_query_name
      def facet_query_count_by_key(facet_query_key)
        facet_queries[facet_query_key.to_s]
      end
      alias :facet_query_count_by_name :facet_query_count_by_key
      
      # Returns the url sent to solr
      def request_url
        query_builder.request_string
      end
      
    end
  end
end
