require 'test_helper'

module Api
  class SessionsControllerTest < ActionController::TestCase
    setup do
      @github_user = User.create!(
        name: 'name',
        email: 'email@example.com'
      )
      @github_user.authorizations.create!(
        provider: 'github',
        uid: 'github_user_id'
      )

      @github_user_with_api_auth = User.create!(
        name: 'name',
        email: 'email@example.com'
      )
      @github_user_with_api_auth.authorizations.create!(
        provider: 'github',
        uid: 'github_user_with_api_auth_id'
      )
      @github_user_with_api_auth.authorizations.create!(
        provider: 'tomatoes',
        token: 'tomatoes_token'
      )

      @github_client = Octokit::Client.new
    end

    teardown do
      User.destroy_all
    end

    test 'given a github access token, '\
        'associated with an existing user, '\
        'it should create a new session' do
      Octokit::Client.expects(:new).with(access_token: 'github_access_token').returns(@github_client)
      @github_client.expects(:user).returns(id: 'github_user_id')

      assert_difference('@github_user.reload.authorizations.count') do
        post :create, provider: 'github', access_token: 'github_access_token'
      end
      assert_response :success
      assert_equal 'application/json', @response.content_type
      assert JSON.parse(@response.body).key?('token')
    end

    test 'given a github access token, '\
        'associated with an existing user, '\
        'with an existing session, '\
        'it should create a new session' do
      Octokit::Client.expects(:new).with(access_token: 'github_access_token').returns(@github_client)
      @github_client.expects(:user).returns(id: 'github_user_with_api_auth_id')

      assert_difference('@github_user_with_api_auth.reload.authorizations.count') do
        post :create, provider: 'github', access_token: 'github_access_token'
      end
      assert_response :success
      assert_equal 'application/json', @response.content_type
      assert JSON.parse(@response.body).key?('token')
    end

    test 'given a github access token, '\
        'not associated with any user, '\
        'it should create a new user' do
      Octokit::Client.expects(:new).with(access_token: 'github_access_token').returns(@github_client)
      @github_client.expects(:user).returns(id: 'new_github_user_id')

      assert_difference('User.count') do
        post :create, provider: 'github', access_token: 'github_access_token'
      end
      assert_response :success
      assert_equal 'application/json', @response.content_type
      assert JSON.parse(@response.body).key?('token')
    end

    test 'given an invalid github access token, it should return an error' do
      Octokit::Client.expects(:new).with(access_token: 'github_access_token').returns(@github_client)
      @github_client.expects(:user).raises(Octokit::Unauthorized)

      post :create, provider: 'github', access_token: 'github_access_token'
      assert_response :unauthorized
      assert_equal 'application/json', @response.content_type
      assert_equal({ error: 'authentication failed' }.to_json, @response.body)
    end

    test 'given an invalid provider, it should return an error' do
      post :create, provider: 'invalid_provider'
      assert_response :bad_request
      assert_equal 'application/json', @response.content_type
      assert_equal({ error: 'provider not supported' }.to_json, @response.body)
    end

    test 'given an authenticated user, it should destroy any tomatoes session' do
      Octokit::Client.stubs(:new).returns(@github_client)
      @github_client.stubs(:user).returns(id: 'github_user_with_api_auth_id')

      post :create, provider: 'github', access_token: 'github_access_token'
      tomatoes_auth = @github_user_with_api_auth.reload.authorizations.where(provider: 'tomatoes').first

      assert_difference('@github_user_with_api_auth.reload.authorizations.count', -2) do
        delete :destroy, token: tomatoes_auth.token
      end
      assert_empty @github_user_with_api_auth.authorizations.where(provider: 'tomatoes')
      assert_response :no_content
    end

    test 'given an invalid token, it should return an error' do
      delete :destroy, token: 'invalid_token'
      assert_response :unauthorized
      assert_equal 'application/json', @response.content_type
      assert_equal({ error: 'authentication failed' }.to_json, @response.body)
    end
  end
end
