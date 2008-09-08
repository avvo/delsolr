#
# DelSolr
# 
# ben@avvo.com 9.1.2008
#
# see README.txt
#

require 'net/http'

require 'digest/md5'

require File.join(File.dirname(__FILE__), 'delsolr', 'version')
require File.join(File.dirname(__FILE__), 'delsolr', 'response')
require File.join(File.dirname(__FILE__), 'delsolr', 'configuration')
require File.join(File.dirname(__FILE__), 'delsolr', 'query_builder')
require File.join(File.dirname(__FILE__), 'delsolr', 'extensions')

module DelSolr
  
  class Client
    
    attr_reader :configuration, :connection
    
    #
    # [<b><tt>:server</tt></b>]
    #   the server you want to connect to
    #   
    # [<b><tt>:port</tt></b>]
    #   the port you want to connect to
    #   
    # [<b><tt>:cache</tt></b>]
    #   (optional) a cache instance (any object the supports get and set)
    # 
    # [<b><tt>:shortcuts</tt></b>]
    #   (options) a list of values in the doc fields to generate short cuts for (ie: [:scores, :id], you will be able to call <tt>rsp.scores</tt> and have it return an array of scores, likewise for <tt>ids</tt>.) Defaults to [:id, :unique_id, :score]
    def initialize(options = {})
      @configuration = DelSolr::Client::Configuration.new(options[:server], options[:port])
      @cache = options[:cache]
      @shortcuts = options[:shortcuts]
    end
    
    #
    #
    # <tt>request_handler</tt> - type of query to perform (should match up w/ request handlers defined in solrconfig.xml)
    # 
    # 
    # options 
    # 
    # [<b><tt>:query</tt></b>]
    #   (required) effectively the 'q' param in the solr URL. The treatment of <tt>:query</tt> depends on the type
    #   of request handler you are using.  The supported values are Strings and Hashes.  Any valid Lucene query string is acceptable
    #   (ie: :query => "brand:apple" and :query => "apply" are both valid).  If given a Hash delsolr will build the appropriate
    #   query string given a hash of fieldnames => values.  For instance, the following two queries are effectively the
    #   same.  Both will end up passing "brand:apple" as the 'q' param to solr.
    # 
    #          c.query('standard', :query => {:brand => 'apple'})
    #          c.query('standard', :query => "brand:apple")
    # 
    # [<b><tt>:filters</tt></b>]
    #   (optional)array, string, or hash of additional filters to apply.  Filters end up in the 'fq' param in the solr query URL.
    #   The value can be a String, Array of Strings, or Hash.  The following are all equivelent.  
    # 
    #          c.query('standard', :query => 'abc', :filters => {:instock => true})
    #          c.query('standard', :query => 'abc', :filters => "instock:true")
    #          c.query('standard', :query => 'abc', :filters => ["instock:true"])
    #          
    #   as are the following
    #          
    #          c.query('standard', :query => 'abc', :filters => {:instock => true, :onsale => true})
    #          c.query('standard', :query => 'abc', :filters => ["instock:true", "onsale:true"])
    #          
    # 
    # [<b><tt>:facets</tt></b>]
    #   (optional) array of hashes for all the facet params (ie: {:field => 'instock_b', :limit => 15, :mincount => 5})
    # 
    #   <em>Faceting by field...</em>
    #          
    #          c.query('standard', :query => 'abc', :facets => [{:field => 'brand', :limit => 15, :mincount => 5}])
    #          
    #   ...will request counts for the 'brand' field name that have a minimum of 5 documents, returning
    #   a max/limit of 15.  The counts for this facet can be pulled from the response like so:
    #          
    #          rsp.facet_field_count('brand', 'Apple') => 17 # returns count as fixnum
    #          
    #   The list of values for this facet can be pulled from the response like so:
    #          
    #          rsp.facet_field_values('brand') => ['Apple', 'Microsoft', 'Dell'] # returns an array of strings
    #          
    #   <em>Faceting by query...</em>
    #   
    #          c.query('standard', :query => 'abc',
    #                              :facets => [:query => {:city => 'seattle', :instock => true},
    #                                          :name => 'seattle_instock'}])
    #          
    #   ...will request counts for the number of documents where "seattle" matches on the "city" field and "instock" is set to true.
    #   Faceting by query requires you to assign a name to the facet so the counts can easily be fetched from the response.  Solr 
    #   resolves facet querys to count by the actual facet query string, which can be cumbersome.  The delsolr response object maintains
    #   a mapping of query name => query string for you so your application only needs to remember the query name.
    #    
    #   The count for this facet query can be pulled like so:
    #   
    #          rsp.facet_query_count_by_name('seattle_instock').
    # 
    # [<b><tt>:sorts</tt></b>]
    #   (optional) array or string of sorts in Lucene syntax (<fieldname> <asc/desc>)
    #   
    #          c.query('standard', :query => 'abc', :sort => "product_name asc")
    #          
    #   
    # [<b><tt>:limit</tt></b>]
    #   (optional) number to return (defaults to 10).  (becomes the 'rows' param in the solr URL)
    #   
    #          c.query('standard', ;query => 'abc', :limit => 100)
    # 
    # [<b><tt>:offset</tt></b>]
    #   (optional) offset (defaults to 0, becomes the 'start' param in the solr URL)
    #   
    #          c.query('standard', :query => 'abc', :offset => 40)
    #   
    # [<b><tt>:enable_caching</tt></b>]
    #   (optional) switch to control whether or not to use the cache (for fetching or setting) for the current query.  Only works if a cache store was passed to the constructor.
    #
    #          c = DelSolr::Client.new(:server => 'solr1', :port => 8983, :cache => SomeCacheStore.new)
    #          c.query('standard', :query => 'abc', :filters => {:instock => true}, :enable_caching => true)
    #          c.query('standard', :query => 'abc', :filters => {:instock => true}, :enable_caching => true) # this one should hit the cache
    #          
    #   Cache keys are created from MD5's of the solr URL that is generated.
    #
    # [<b><tt>:boot</tt></b>] becomes the 'bq' param which is used for query time boosting
    # [<b><tt>:fields</tt></b>] becomes the 'fl' param which decides which fields to return.  Defaults to 'id,unique_id,score'
    # 
    # NOTE: Any unrecognized options will be passed along as URL params in the solr request URL.  This allows you to access solr features
    # which are unsupported by DelSolr.
    #
    # Returns a DelSolr::Client::Response instance
    def query(request_handler, opts = {})

      raise "request_handler must be supplied" if request_handler.blank?

      enable_caching = opts.delete(:enable_caching) && !@cache.nil?
      ttl = opts.delete(:ttl) || 1.hours

      query_builder = DelSolr::Client::QueryBuilder.new(request_handler, opts)

      # it's important that the QueryBuilder returns strings in a deterministic fashion
      # so that the cache keys will match for the same query.
      cache_key = Digest::MD5.hexdigest(query_builder.request_string)
      from_cache = false

      # if we're caching, first try looking in the cache
      if enable_caching
        body = @cache.get(cache_key) rescue body = nil
        from_cache = true unless body.blank?
      end

      if body.blank? # cache miss (or wasn't enabled)

        # only bother to create the connection if we know we failed to hit the cache
        @connection ||= Net::HTTP.new(configuration.server, configuration.port)      
        raise "Failed to connect to #{configuration.server}:#{configuration.port}" if @connection.nil?

        header, body = @connection.get(query_builder.request_string)

        # add to the cache if caching
        if enable_caching
          begin
            @cache.set(cache_key, body, ttl)
          rescue
          end
        end
      end

      DelSolr::Client::Response.new(body, query_builder, :from_cache => from_cache, :shortcuts => @shortcuts)
    end

  end
end
