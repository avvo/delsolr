require File.dirname(__FILE__) + '/test_helper'

class DocumentTest < Test::Unit::TestCase

  include Test::Unit::Assertions
  
  def test_create
    d = DelSolr::Document.new
    assert(d)
    
    d.add_field('person_name', 'John Smith')
    
    buf = "<doc>\n<field name=\"person_name\">John Smith</field>\n</doc>"
    
    assert_equal(buf, d.xml)
  end
  
  def test_cdata
    d = DelSolr::Document.new
    assert(d)
    
    d.add_field('person_name', 'John Smith', :cdata => true)
    
    buf = "<doc>\n<field name=\"person_name\"><![CDATA[John Smith]]></field>\n</doc>"
    
    assert_equal(buf, d.xml)
  end
  
end
