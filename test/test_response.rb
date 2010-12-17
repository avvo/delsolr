require File.expand_path(File.dirname(__FILE__)) + '/test_helper'

class ResponseTest < Test::Unit::TestCase

  include Test::Unit::Assertions

  @@test_001 = %{
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
        '19596' => 392},
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
  
  def test_001
    r = nil
    qb = DelSolr::Client::QueryBuilder.new('standard', :query => {:index_type => 'widget'}, :facets => {:query => 'city_idm:19596', :prefix => {:key => 19596}} )
    qb.request_string # need to generate this...
    assert_nothing_raised { r = DelSolr::Client::Response.new(@@test_001, qb) }
    
    assert_equal(151, r.qtime)
    assert_equal(1.5583541, r.max_score)
    assert_equal(10, r.docs.length)
    assert_equal([1, 3, 4, 5, 7, 8, 9, 10, 11, 12], r.ids)
    assert_equal({
        'available_b'=>[
          'false',1328],
        'onsale_b'=>[
          'false',1182,
          'true',174]}, r.facet_fields)
    assert_equal(1182, r.facet_field_count('onsale_b', false))
    assert_equal(174, r.facet_field_count('onsale_b', true))
    assert_equal(1328, r.facet_field_count('available_b', false))
    assert_equal(392, r.facet_query_count_by_key(19596))
  end
  
  def test_shortcuts
    r = nil
    qb = DelSolr::Client::QueryBuilder.new('standard', :query => {:index_type => 'widget'}, :facets => {:query => 'city_idm:19596', :prefix => {:key => 19596}} )
    qb.request_string # need to generate this...
    assert_nothing_raised { r = DelSolr::Client::Response.new(@@test_001, qb, :shortcuts => [:index_type, :id]) }
    
    assert(r.respond_to?(:index_types))
    assert(r.respond_to?(:ids))
    assert(!r.respond_to?(:scores))
  end

end
