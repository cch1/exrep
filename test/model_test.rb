require File.dirname(__FILE__) + '/test_helper.rb'

class ModelTest < ActiveSupport::TestCase
  fixtures :users
  
  CSVLineRegexp = /^("?)[^"\r\n]*\1(,("?)[^"\r\n]+\3)*$/
  CSVRegexp = /(("?)[^"\r\n]*\2(,("?)[^"\r\n]+\4)*\n)+\Z/m

  def test_should_serialize_instance_as_CSV
    assert_match CSVLineRegexp, users(:chris).to_csv
  end

  def test_should_serialize_array_as_CSV
    assert_match CSVRegexp, User.all.to_csv
    assert_match /id(,\w*)*,lastname/, User.all.to_csv
  end
end