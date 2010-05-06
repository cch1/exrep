require File.expand_path(File.dirname(__FILE__) + "/application/test/test_helper.rb")

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

  test 'should respect exrep_methods enumerator' do
    assert csv = RichUser.all.to_csv
    assert_no_match /id(,\w*)*,security_token/, csv
  end

  test 'should meld with attrs' do
    assert csv = RichUser.all.to_csv(:with => :security_token)
    assert_match /id(,\w*)*,security_token/, csv
    assert_match /#{users(:pascale).security_token}/, csv
  end
end