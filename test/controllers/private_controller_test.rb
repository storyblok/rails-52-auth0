require 'test_helper'

class PrivateControllerTest < ActionDispatch::IntegrationTest
  test "should get hello" do
    get private_hello_url
    assert_response :success
  end

end
