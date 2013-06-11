require 'test_helper'

class BooksController < ActionController::Base
  def create
    params.require(:book).require(:name)
    head :ok
  end
end

class ActionControllerRequiredParamsTest < ActionController::TestCase
  tests BooksController

  test "missing required parameters will raise exception" do
    post :create, { :magazine => { :name => "Mjallo!" } }
    assert_response :bad_request

    post :create, { :book => { :title => "Mjallo!" } }
    assert_response :bad_request
  end

  test "missing required parameters can log a message" do
    begin
      ActionController::Parameters.action_on_missing_parameter = :log
      assert_logged "Missing parameter: name\n" do
        post :create, { :book => { :title => "Mjallo!" } }
      end
    ensure
      ActionController::Parameters.action_on_missing_parameter = :raise
    end
  end

  test "required parameters that are present will not raise" do
    post :create, { :book => { :name => "Mjallo!" } }
    assert_response :ok
  end

  test "missing parameters will be mentioned in the return" do
    post :create, { :magazine => { :name => "Mjallo!" } }
    assert_equal "Required parameter missing: book", response.body
  end
end
