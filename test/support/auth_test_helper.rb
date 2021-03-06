module AuthTestHelper
  extend ActiveSupport::Concern

  # Controller will fetch current user from warden.
  # Make it pick up our current_user
  included do
    setup do
      request.env['warden'] ||= stub :user => nil
    end
  end

  def login(user_or_method_hash = {})
    if user_or_method_hash.respond_to?(:reverse_merge)
      user_or_method_hash.reverse_merge! :is_admin? => false
    end
    @current_user = stub_record(:user, user_or_method_hash)
    request.env['warden'] = stub :user => @current_user
    request.env['HTTP_AUTHORIZATION'] = header_for_token_auth
    return @current_user
  end

  def assert_login_required
    assert_access_denied(true, false)
  end

  def assert_access_denied(denied = true, logged_in = true)
    if denied
      if @response.content_type == 'application/json'
        assert_json_response('error' => I18n.t(:not_authorized))
        assert_response :unprocessable_entity
      else
        if logged_in
          assert_equal({:alert => I18n.t(:not_authorized)}, flash.to_hash)
          assert_redirected_to home_url
        else
          assert_equal({:alert => I18n.t(:not_authorized_login)}, flash.to_hash)
          assert_redirected_to login_url
        end
      end
    else
      assert flash[:alert].blank?
    end
  end

  def expect_logout
    expect_warden_logout
    @token.expects(:destroy) if @token
  end

  protected

  def header_for_token_auth
    @token = stub_record(:token, :authenticate => @current_user)
    Token.stubs(:find_by_token).with(@token.token).returns(@token)
    ActionController::HttpAuthentication::Token.encode_credentials @token.token
  end

  def expect_warden_logout
    raw = mock('raw session') do
      expects(:inspect)
    end
    request.env['warden'].expects(:raw_session).returns(raw)
    request.env['warden'].expects(:logout)
  end

end

class ActionController::TestCase
  include AuthTestHelper
end
