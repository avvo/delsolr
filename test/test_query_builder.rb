require File.expand_path(File.dirname(__FILE__)) + '/test_helper'

class QueryBuilderTest < Test::Unit::TestCase

  include Test::Unit::Assertions
  
  def test_001
    qb = nil
    
    opts = {}
    opts[:limit] = 13
    opts[:offset] = 3
    opts[:fl] = 'id'
    opts[:query] = 'good book'
    
    assert_nothing_raised { qb = DelSolr::Client::QueryBuilder.new('query_name', opts) }
    
    assert(qb)
    
    p = get_params(qb.request_string)
    assert_equal('3', p['start'])
    assert_equal('13', p['rows'])
    assert_equal('id', p['fl'])
    assert_equal('good book', p['q'])
  end
  
  def test_002
    qb = nil
    
    opts = {}
    opts[:query] = "blahblah"
    opts[:fields] = 'id,unique_id,score'
    
    assert_nothing_raised { qb = DelSolr::Client::QueryBuilder.new('query_name', opts) }
    
    assert(qb)
    
    p = get_params(qb.request_string)
    assert_equal('id,unique_id,score', p['fl'])
    assert_equal('blahblah', p['q'])
  end
  
  def test_003
    qb = nil
    
    opts = {}
    opts[:query] = {:index_type => 'books'}
    opts[:fields] = 'id,unique_id,score'
    
    assert_nothing_raised { qb = DelSolr::Client::QueryBuilder.new('query_name', opts) }
    
    assert(qb)
    
    p = get_params(qb.request_string)
    assert_equal('id,unique_id,score', p['fl'])
    assert_equal('index_type:books', p['q'])
  end
  
  def test_004
    qb = nil
    
    opts = {}
    opts[:query] = {:index_type => 'books'}
    opts[:filters] = {:location => 'seattle'}
    
    assert_nothing_raised { qb = DelSolr::Client::QueryBuilder.new('query_name', opts) }
    
    assert(qb)
    
    p = get_params(qb.request_string)
    assert_equal('location:seattle', p['fq'])
    assert_equal('index_type:books', p['q'])
  end

  def test_005
    qb = nil
    
    opts = {}
    opts[:query] = {:index_type => 'books'}
    opts[:filters] = "location:seattle"
    
    assert_nothing_raised { qb = DelSolr::Client::QueryBuilder.new('query_name', opts) }
    
    assert(qb)

    p = get_params(qb.request_string)
    
    assert_equal('location:seattle', p['fq'])
    assert_equal('index_type:books', p['q'])
  end
  
  def test_facets_001
    qb = nil
    opts = {}
    opts[:query] = "games"
    opts[:facets] = [{:field => 'instock_b'}, {:field => 'on_sale_b', :limit => 1}]
    
    assert_nothing_raised { qb = DelSolr::Client::QueryBuilder.new('onebox-books', opts) }
    
    assert(qb)
    
    p = get_params(qb.request_string)
    
    assert_equal('true', p['facet'])
    assert_equal(['instock_b', 'on_sale_b'].sort, p['facet.field'].sort)
    assert_equal('1', p['f.on_sale_b.facet.limit'])
  end
  
  def test_facets_002
    qb = nil
    opts = {}
    opts[:query] = "games"
    opts[:facets] = [{:query => {:city_idm => 19596}, :name => 'seattle'}, {:field => 'language_idm'}]
    
    assert_nothing_raised { qb = DelSolr::Client::QueryBuilder.new('onebox-books', opts) }
    
    assert(qb)
    
    p = get_params(qb.request_string)
    
    assert_equal('true', p['facet'])
    assert_equal('language_idm', p['facet.field'])
    assert_equal('{!key=seattle}city_idm:19596', p['facet.query'])
  end

  def test_facets_003
    qb = nil
    opts = {}
    opts[:query] = "games"
    opts[:facets] = [{:query => {:city_idm => 19596}, :localparams => {:key => 'seattle', :ex => 'exclusion'}}, {:field => 'language_idm'}]

    assert_nothing_raised { qb = DelSolr::Client::QueryBuilder.new('onebox-books', opts) }

    assert(qb)

    p = get_params(qb.request_string)

    assert_equal('true', p['facet'])
    assert_equal('language_idm', p['facet.field'])
    assert_equal('{!key=seattle ex=exclusion}city_idm:19596', p['facet.query'])
  end

  def test_range
    qb = nil
    opts = {}
    opts[:query] = "games"
    opts[:filters] = {:id => (1..3)}
    
    assert_nothing_raised { qb = DelSolr::Client::QueryBuilder.new('onebox-books', opts) }
    
    assert(qb)
    
    p = get_params(qb.request_string)
    
    assert_equal(p['fq'], 'id:[1 TO 3]')
  end

  
private
  
  # given a url returns a hash of the query params (for each duplicate key, it returns an array)
  def get_params(url)
    query = URI.parse(url).query
    query = query.split('&')
    h = {}
    query.each do |p|
      a = p.split('=')
      if h[a[0]]
        h[a[0]] = (Array(h[a[0]]) << CGI::unescape(a[1])) # convert it to an array
      else
        h[a[0]] = CGI::unescape(a[1])
      end
    end
    h
  end

  
end
