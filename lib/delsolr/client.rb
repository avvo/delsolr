module DelSolr

  class Client
    autoload :Configuration, "delsolr/client/configuration"
    autoload :QueryBuilder, "delsolr/client/query_builder"
    autoload :Response, "delsolr/client/response"

    attr_reader :configuration, :logger

    class ConnectionError < StandardError; end

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
    def initialize(options = {}, &connection_block)
      @configuration = DelSolr::Client::Configuration.new(options[:server], options[:port], options[:timeout], options[:path])
      @cache = options[:cache]
      @logger = options[:logger]
      @shortcuts = options[:shortcuts]
      setup_connection(&connection_block) if connection_block
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
        response = begin
          connection.post("#{configuration.path}/select", query_builder.request_string)
        rescue Faraday::Error::ClientError => e
          raise ConnectionError, e.message
        end

        code = response.respond_to?(:code) ? response.code : response.status
        unless (200..299).include?(code.to_i)
          raise ConnectionError, "Connection failed with status: #{code}"
        end

        body = response.body

        # We get UTF-8 from Solr back, make sure the string knows about it
        # when running on Ruby >= 1.9
        if body.respond_to?(:force_encoding)
          body.force_encoding("UTF-8")
        end

      end

      response = DelSolr::Client::Response.new(body, query_builder, :logger => logger, :from_cache => from_cache, :shortcuts => @shortcuts)

      url = "http://#{configuration.full_path}/select?#{query_builder.request_string}"
      if response && response.success?
        log_query_success(url, response, from_cache, (from_cache ? cache_time : response.qtime))
      else
        # The response from solr will already be logged, but we should also
        # log the full url to make debugging easier
        log_query_error(url)
      end

      # Cache successful responses that don't come from the cache
      if response && response.success? && enable_caching && !from_cache
        # add to the cache if caching
        @cache.set(cache_key, body, ttl)
      end

      response
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
    def update!(docs, options = {})
      update(docs) && post_update!(options)
    end

    # Calls <tt>update!</tt> on the docs and then <tt>commit!</tt>
    def update_and_commit!(docs, options = {})
      update!(docs, options) && commit!
    end

    # posts the buffer created by <tt>update</tt> to solr
    def post_update!(options = {})
      rsp = post(prepare_update_xml(options))
      success?(rsp.body) or log_error(rsp.body)
    end

    # deletes <tt>unique_id</tt> from the index
    def delete(unique_id)
      rsp = post("<delete><id>#{unique_id}</id></delete>")
      success?(rsp.body) or log_error(rsp.body)
    end

    # deletes documents matching <tt>query</tt> from the index
    def delete_by_query(query)
      rsp = post("<delete><query>#{query}</query></delete>")
      success?(rsp.body) or log_error(rsp.body)
    end

    # commits all pending adds/deletes
    def commit!
      rsp = post("<commit/>")
      success?(rsp.body) or log_error(rsp.body)
    end

    # posts the optimize directive to solr
    def optimize!
      rsp = post("<optimize/>")
      success?(rsp.body) or log_error(rsp.body)
    end

    def setup_connection(&connection_block)
      @connection_block = connection_block
    end

    # accessor to the connection instance
    def connection
      @connection ||= begin
        Faraday.new(:url => "http://#{configuration.server}:#{configuration.port}", :timeout => configuration.timeout, &connection_block)
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

    def connection_block
      @connection_block ||= lambda do |faraday|
        faraday.adapter Faraday.default_adapter
      end
    end

    def log_query_success(url, response, from_cache, query_time)
      if logger
        l = []
        l << "#{query_time}ms"
        l << (from_cache ? "CACHE" : "SOLR")
        l << url
        logger.info l.join(' ')
      end
    end

    def log_query_error(url)
      logger.error "ERROR #{url}" if logger
    end

    # returns the update xml buffer
    def prepare_update_xml(options = {})
      r = ["<add#{options.to_xml_attribute_string}>\n"]
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
      response_body.include?('<result status="0"></result>') ||
        response_body.include?('<lst name="responseHeader"><int name="status">0</int>')
    end

    def log_error(response_body)
      return unless logger
      logger.error(response_body)
    end
  end
end
