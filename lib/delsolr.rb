#
# DelSolr
# 
# ben@avvo.com 9.1.2008
#
# see README.txt
#


require 'net/http'

require 'digest/md5'

require File.join(File.dirname(__FILE__), 'delsolr', 'response')
require File.join(File.dirname(__FILE__), 'delsolr', 'configuration')
require File.join(File.dirname(__FILE__), 'delsolr', 'query_builder')
require File.join(File.dirname(__FILE__), 'delsolr', 'document')
require File.join(File.dirname(__FILE__), 'delsolr', 'extensions')


module DelSolr
  
  class Client
    
    attr_reader :configuration, :logger
    
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
    #   (optional) a list of values in the doc fields to generate short cuts for (ie: [:scores, :id], you will be able to call <tt>rsp.scores</tt> and have it return an array of scores, likewise for <tt>ids</tt>.) Defaults to [:id, :unique_id, :score]
    #
    # [<b><tt>:path</tt></b>]
    #   (optional) the path of the solr install (defaults to "/solr")
    #
    # [<b><tt>:logger</tt></b>]
    #   (optional) Log4r logger object
    def initialize(options = {})
      @configuration = DelSolr::Client::Configuration.new(options[:server], options[:port], options[:timeout], options[:path])
      @cache = options[:cache]
      @logger = options[:logger]
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
    #                                          :prefix => {:key => 'seattle_instock'}}])
    #          
    #   ...will request counts for the number of documents where "seattle" matches on the "city" field and "instock" is set to true.
    #   Faceting by query requires you to assign a name to the facet so the counts can easily be fetched from the response.  Solr 
    #   resolves facet querys to count by the actual facet query string, which can be cumbersome.  The delsolr response object maintains
    #   a mapping of query name => query string for you so your application only needs to remember the query name.
    #    
    #   The count for this facet query can be pulled like so:
    #   
    #          rsp.facet_query_count_by_key('seattle_instock').
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
        t1 = Time.now
        body = @cache.get(cache_key) rescue body = nil
        from_cache = true unless body.blank?
        cache_time = (Time.now - t1).to_i * 1000 # retrieval time from the cache in ms
      end

      if body.blank? # cache miss (or wasn't enabled)
        header, body = connection.get(configuration.path + query_builder.request_string)

        # We get UTF-8 from Solr back, make sure the string knows about it
        # when running on Ruby >= 1.9
        if body.respond_to?(:force_encoding)
          body.force_encoding("UTF-8")
        end

        # add to the cache if caching
        if enable_caching
          begin
            @cache.set(cache_key, body, ttl)
          rescue
          end
        end
      end

      response = DelSolr::Client::Response.new(body, query_builder, :logger => logger, :from_cache => from_cache, :shortcuts => @shortcuts)
      if logger
        if response && response.success?
          response_stat_string = "#{from_cache ? cache_time : response.qtime},#{response.total},"
        end
        logger.info "#{from_cache ? 'C' : 'S'},#{response_stat_string}http://#{configuration.full_path}#{response.request_url}"
      end
      response
    # If we error, just return nil and let the client decide what to do
    rescue StandardError
      logger.info "http://#{configuration.full_path}#{query_builder.request_string}" if logger && configuration && query_builder
      return nil
    end
    
    # Adds a document to the buffer to be posted to solr (NOTE: does not perform the actual post)
    #
    # [<b><tt>docs</tt></b>]
    #            docs must be a DelSolr::Document or array of instances.  See DelSolr::Document for how to setup a document 
    def update(docs)
      self.pending_documents.push(*Array(docs))
      true
    end
    
    # Exactly like <tt>update</tt>, but performs the post immediately. Use <tt>update</tt> if you wish to batch document updates.
    def update!(docs)
      update(docs) && post_update!
    end
    
    # Calls <tt>update!</tt> on the docs and then <tt>commit!</tt>
    def update_and_commit!(docs)
      update!(docs) && commit!
    end
    
    # posts the buffer created by <tt>update</tt> to solr
    def post_update!
      h,b = post(prepare_update_xml())
      success?(b)
    end
    
    # deletes <tt>unique_id</tt> from the index
    def delete(unique_id)
      h,b = post("<delete><id>#{unique_id}</id></delete>")
      success?(b)
    end
    
    # not implemented
    def delete_by_query(query)
      raise 'not implemented yet :('
    end
    
    # commits all pending adds/deletes
    def commit!
      h,b = post("<commit/>")
      success?(b)
    end
    
    # posts the optimize directive to solr
    def optimize!
      h,b = post("<optimize/>")
      success?(b)
    end

    # accessor to the connection instance
    def connection
      @connection ||= begin
        c = Net::HTTP.new(configuration.server, configuration.port)
        c.read_timeout = configuration.timeout
        raise "Failed to connect to #{configuration.server}:#{configuration.port}" if c.nil?
        c
      end
    end

    # clears out the connection so a new one will be created
    def reset_connection!
      @connection = nil
    end
    
    # returns the array of documents that are waiting to be posted to solr
    def pending_documents
      @pending_documents ||= []
    end
    
    private
    
    # returns the update xml buffer
    def prepare_update_xml
      r = ["<add>\n"]
      # copy and clear pending docs
      working_docs, @pending_documents = @pending_documents, nil
      working_docs.each { |doc| r << doc.xml }
      r << "\n</add>\n"
      r.join # not sure, but I think Array#join is faster then String#<< for large buffers
    end
    
    # helper for posting data to solr
    def post(buffer)
      connection.post("#{configuration.path}/update", buffer, {'Content-type' => 'text/xml;charset=utf-8'})
    end
    
    def success?(response_body)
      response_body == '<result status="0"></result>'
    end
    
  end
end
