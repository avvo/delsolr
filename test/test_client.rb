require File.expand_path(File.dirname(__FILE__)) + '/test_helper'
require 'rubygems'
gem 'mocha', '>=0.9.0'
require 'mocha'

class ClientTest < Test::Unit::TestCase

  include Test::Unit::Assertions

  SUCCESS = '<result status="0"></result>'
  SOLR_34_SUCCESS = %Q{<?xml version="1.0" encoding="UTF-8"?>
<response>
<lst name="responseHeader"><int name="status">0</int><int name="QTime">4</int></lst>
</response>}
  FAILURE = '<result status="1"></result>'
  CONTENT_TYPE = {'Content-type' => 'text/xml;charset=utf-8'}

  class TestCache
    def set(k,v,t)
      @cache ||= {}
      @cache[k] = v
    end

    def get(k)
      @cache ||= {}
      @cache[k]
    end
  end

  @@response_buffer = %{
    {
     'responseHeader'=>{
      'status'=>0,
      'QTime'=>151,
      'params'=>{
            'wt'=>'ruby',
            'rows'=>'10',
            'explainOther'=>'',
            'start'=>'0',
            'hl.fl'=>'',
            'indent'=>'on',
            'hl'=>'on',
            'q'=>'index_type:widget',
            'fl'=>'*,score',
            'qt'=>'standard',
            'version'=>'2.2'}},
     'response'=>{'numFound'=>1522698,'start'=>0,'maxScore'=>1.5583541,'docs'=>[
            {
             'index_type'=>'widget',
             'id'=>1,
             'unique_id'=>'1_widget',
             'score'=>1.5583541},
            {
             'index_type'=>'widget',
             'id'=>3,
             'unique_id'=>'3_widget',
             'score'=>1.5583541},
            {
             'index_type'=>'widget',
             'id'=>4,
             'unique_id'=>'4_widget',
             'score'=>1.5583541},
            {
             'index_type'=>'widget',
             'id'=>5,
             'unique_id'=>'5_widget',
             'score'=>1.5583541},
            {
             'index_type'=>'widget',
             'id'=>7,
             'unique_id'=>'7_widget',
             'score'=>1.5583541},
            {
             'index_type'=>'widget',
             'id'=>8,
             'unique_id'=>'8_widget',
             'score'=>1.5583541},
            {
             'index_type'=>'widget',
             'id'=>9,
             'unique_id'=>'9_widget',
             'score'=>1.5583541},
            {
             'index_type'=>'widget',
             'id'=>10,
             'unique_id'=>'10_widget',
             'score'=>1.5583541},
            {
             'index_type'=>'widget',
             'id'=>11,
             'unique_id'=>'11_widget',
             'score'=>1.5583541},
            {
             'index_type'=>'widget',
             'id'=>12,
             'unique_id'=>'12_widget',
             'score'=>1.5583541}]
     },
     'facet_counts'=>{
      'facet_queries'=>{
        'city_idm:19596' => 392},
      'facet_fields'=>{
        'available_b'=>[
          'false',1328],
        'onsale_b'=>[
          'false',1182,
          'true',174]}},
     'highlighting'=>{
      '1_widget'=>{},
      '3_widget'=>{},
      '4_widget'=>{},
      '5_widget'=>{},
      '7_widget'=>{},
      '8_widget'=>{},
      '9_widget'=>{},
      '10_widget'=>{},
      '11_widget'=>{},
      '12_widget'=>{}}}
  }

  def test_create
    s = nil
    assert_nothing_raised do
      s = DelSolr::Client.new(:server => 'localhost', :port => 8983)
    end
    assert(s)
  end

  def test_commit_success
    c = setup_client
    c.connection.expects(:post).once.returns([nil,SUCCESS])
    assert(c.commit!)
  end

  def test_solr_34_success_response_accepted
    c = setup_client
    c.connection.expects(:post).once.returns([nil,SOLR_34_SUCCESS])
    assert(c.commit!)
  end
  
  def test_commit_success
    logger = stub_everything
    c = setup_client(:logger => logger)
    c.connection.expects(:post).once.returns([nil,FAILURE])
    logger.expects(:error).with(FAILURE)
    assert(!c.commit!)
  end

  def test_optimize_success
    c = setup_client
    c.connection.expects(:post).once.returns([nil,SUCCESS])
    assert(c.optimize!)
  end

  def test_optimize_failure
    logger = stub_everything
    c = setup_client(:logger => logger)
    c.connection.expects(:post).once.returns([nil,FAILURE])
    logger.expects(:error).with(FAILURE)
    assert(!c.optimize!)
  end

  def test_update
    c = setup_client

    doc = DelSolr::Document.new
    doc.add_field(:id, 123)
    doc.add_field(:name, 'mp3 player')

    expected_post_data = "<add>\n#{doc.xml}\n</add>\n"

    assert(c.update(doc))
    assert_equal(1, c.pending_documents.length)

    c.connection.expects(:post).with('/solr/update', expected_post_data, CONTENT_TYPE).returns([nil,SUCCESS])
    assert(c.post_update!)
    assert_equal(0, c.pending_documents.length)
  end
  
  def test_error_logged_if_update_fails
    logger = stub_everything
    c = setup_client(:logger => logger)

    doc = DelSolr::Document.new
    doc.add_field(:id, 123)
    doc.add_field(:name, 'mp3 player')

    c.update(doc)
    fail_response =
      "<html>
      <head>
      <meta http-equiv=\"Content-Type\" content=\"text/html; charset=ISO-8859-1\"/>
      <title>Error 400 ERROR:unknown field 'priority'</title>
      </head>
      <body><h2>HTTP ERROR 400</h2>
      <p>Problem accessing /solr/update. Reason:
      <pre>    ERROR:unknown field 'priority'</pre></p>
      </body>
      </html>"
    c.connection.expects(:post).returns([nil, fail_response])
    logger.expects(:error).with(fail_response)
    c.post_update!
  end

  def test_update!
    c = setup_client

    doc = DelSolr::Document.new
    doc.add_field(:id, 123)
    doc.add_field(:name, 'mp3 player')

    expected_post_data = "<add>\n#{doc.xml}\n</add>\n"

    c.connection.expects(:post).with('/solr/update', expected_post_data, CONTENT_TYPE).returns([nil,SUCCESS])
    assert(c.update!(doc))
    assert_equal(0, c.pending_documents.length)
  end

  def test_bang_update_with_options
    c = setup_client

    doc = DelSolr::Document.new
    doc.add_field(:id, 123)
    doc.add_field(:name, 'mp3 player')

    expected_post_data = "<add commitWithin=\"1000\">\n#{doc.xml}\n</add>\n"

    c.connection.expects(:post).with('/solr/update', expected_post_data, CONTENT_TYPE).returns([nil,SUCCESS])
    assert(c.update!(doc, :commitWithin => 1000))
    assert_equal(0, c.pending_documents.length)
  end

  def test_query_returns_nil_when_exception_thrown
    c = setup_client

    mock_query_builder = DelSolr::Client::QueryBuilder
    mock_query_builder.stubs(:request_string).returns('/select?some_query') # mock the query builder
    DelSolr::Client::QueryBuilder.stubs(:new).returns(mock_query_builder)
    c.connection.expects(:post).raises(StandardError) # mock the connection
    assert_nothing_raised do
      r = c.query('standard', :query => '123')
      assert_nil(r)
    end
  end

  def test_query_with_path
    c = setup_client(:path => '/abcsolr')

    mock_query_builder = DelSolr::Client::QueryBuilder
    mock_query_builder.stubs(:request_string).returns('/select?some_query') # mock the query builder
    DelSolr::Client::QueryBuilder.stubs(:new).returns(mock_query_builder)
    c.connection.expects(:post).with("/abcsolr/select", mock_query_builder.request_string).returns([nil, @@response_buffer]) # mock the connection
    r = c.query('standard', :query => '123')
    assert(r)
    assert_equal([1,3,4,5,7,8,9,10,11,12], r.ids.sort)
    assert(!r.from_cache?, 'should not be from cache')
  end

  def test_query_with_default_path
    c = setup_client

    mock_query_builder = DelSolr::Client::QueryBuilder
    mock_query_builder.stubs(:request_string).returns('/select?some_query') # mock the query builder
    DelSolr::Client::QueryBuilder.stubs(:new).returns(mock_query_builder)
    c.connection.expects(:post).with("/solr/select", mock_query_builder.request_string).returns([nil, @@response_buffer]) # mock the connection
    r = c.query('standard', :query => '123')
    assert(r)
    assert_equal([1,3,4,5,7,8,9,10,11,12], r.ids.sort)
    assert(!r.from_cache?, 'should not be from cache')
  end


  def test_query_from_cache
    c = setup_client(:cache => TestCache.new)

    mock_query_builder = DelSolr::Client::QueryBuilder
    mock_query_builder.stubs(:request_string).returns('/select?some_query') # mock the query builder
    DelSolr::Client::QueryBuilder.stubs(:new).returns(mock_query_builder)
    c.connection.expects(:post).with("/solr/select", mock_query_builder.request_string).returns([nil, @@response_buffer]) # mock the connection
    r = c.query('standard', :query => '123', :enable_caching => true)
    assert(r)
    assert_equal([1,3,4,5,7,8,9,10,11,12], r.ids.sort)
    assert(!r.from_cache?, 'should not be from cache')

    r = c.query('standard', :query => '123', :enable_caching => true)
    assert(r)
    assert_equal([1,3,4,5,7,8,9,10,11,12], r.ids.sort)
    assert(r.from_cache?, 'this one should be from the cache')
  end

  if RUBY_VERSION.to_f >= 1.9
    def test_query_encoding_ruby19_ut8
      c = setup_client

      mock_query_builder = DelSolr::Client::QueryBuilder
      mock_query_builder.stubs(:request_string).returns('/select?some_query') # mock the query builder
      DelSolr::Client::QueryBuilder.stubs(:new).returns(mock_query_builder)
      c.connection.expects(:post).with("/solr/select", mock_query_builder.request_string).returns([nil, @@response_buffer]) # mock the connection
      r = c.query('standard', :query => '123')
      assert(r)

      ensure_encoding = lambda { |v|
        case v
          when String; assert_equal 'UTF-8', v.encoding.name
          when Array; v.each(&ensure_encoding)
          when Hash; (v.keys + v.values).each(&ensure_encoding)
        end
      }

      ensure_encoding.call(r.raw_response)
    end
  end

  def test_delete
    c = setup_client
    id = 123
    expected_post_data = "<delete><id>#{id}</id></delete>"
    c.connection.expects(:post).with('/solr/update', expected_post_data, CONTENT_TYPE).returns([nil,SUCCESS])
    assert(c.delete(id))
  end
  
  def test_delete_by_query
    c = setup_client
    query = "*:*"
    expected_post_data = "<delete><query>#{query}</query></delete>"
    c.connection.expects(:post).with('/solr/update', expected_post_data, CONTENT_TYPE).returns([nil,SUCCESS])
    assert(c.delete_by_query(query))
  end
private

  def setup_client(options = {})
    DelSolr::Client.new({:server => 'localhost', :port => 8983}.merge(options))
  end

end
