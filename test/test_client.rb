require File.dirname(__FILE__) + '/test_helper'

class ClientTest < Test::Unit::TestCase

  include Test::Unit::Assertions
  
  def test_create
    s = nil
    assert_nothing_raised do
      s = DelSolr::Client.new(:server => 'localhost', :port => 8983)
    end
    assert(s)
  end
  
end
