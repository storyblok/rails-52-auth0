require 'test_helper'

class PublicControllerTest < ActionDispatch::IntegrationTest
  test "should get hello" do
    get public_hello_url
    assert_response :success
  end

end
