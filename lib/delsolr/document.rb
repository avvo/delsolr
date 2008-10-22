module DelSolr
  #
  # DelSolr::Client::Document
  # 
  # Generally, indexing consists of iterating over your database, creating a huge xml buffer, and
  # posting it to solr.  This wraps up the xml portion and DelSolr::Client wraps up the posting/batching
  # portions.
  # 
  # This is what your indexing logic might look like if you're dealing w/ ActiveRecord objects:
  # 
  #          client = DelSolr::Client.new(:server => 'solr1', :port => 8983, :timout => 500)
  #          models = SomeModel.find(:all)
  #          models.each do |model|
  #            doc = DelSolr::Document.new
  #            doc.add_field('id', model.id)
  #            doc.add_field('name', model.name)
  #            model.tags.each do |tag| # multiple tag fields
  #              doc.add_field('tag', tag.name)
  #            end
  #            client.update(doc) # batch the document update
  #          end
  #          client.post_update! # send the batch to solr
  #          client.commit! # send the commit so solr updates the index
  #  
  # It's generally a good idea to experiment with different batch size.  500-2000 documents per post
  # is a good starting point depending on how large your documents are.
  # 
  # You also may want to just update a signle document when it is changed.  Might looks like this:
  # 
  #          def after_save
  #            doc = DelSolr::Document.new
  #            doc.add_field('id', model.id)
  #            doc.add_field('name', model.name)
  #            $client.update_and_commit!(doc) # post the document and immediately post the commit
  #          end
  # 
  #
  class Document

    # [<b><tt>field_mame</tt></b>]
    #         is the name of the field in your schema.xml
    # [<b><tt>value</tt></b>]
    #         is the value of the field you wish to be indexed
    # [<b><tt>options</tt></b>]
    #         <b><tt>:cdata</tt></b>  set to true if you want the value wrap in a CDATA tag
    #         
    #         All other options are passed directly as xml attributes (see the solr documentation on usage)
    def add_field(field_name, value, options = {})
      field_buffer << construct_field_tag(field_name, value, options)
    end

    def xml
      "<doc>\n" + field_buffer + "</doc>"
    end

    private

    # creates xml field for given inputs
    def construct_field_tag(name, value, options={})
      options[:name] = name.to_s
      use_cdata = options.delete(:cdata)
      opts = []
      options.each do |k,v| 
        opts.push "#{k}=\"#{v}\""
      end
      opts = opts.join(" ")
      opts = " " + opts if opts

      return "<field#{opts}>#{use_cdata ? cdata(value) : value}</field>\n"
    end  

    def cdata(str)
      "<![CDATA[#{str}]]>"
    end

    def field_buffer
      @buffer ||= ""
    end

  end
  
end