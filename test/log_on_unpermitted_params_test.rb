require 'test_helper'
require 'action_controller/parameters'

class LogOnUnpermittedParamsTest < ActiveSupport::TestCase
  def setup
    ActionController::Parameters::Filter.action_on_unpermitted_parameters = :log
  end

  def teardown
    ActionController::Parameters::Filter.action_on_unpermitted_parameters = false
  end

  test "logs on unexpected params" do
    params = ActionController::Parameters.new({
      :book => { :pages => 65 },
      :fishing => "Turnips"
    })

    assert_logged("Unpermitted parameters: fishing") do
      params.permit(:book => [:pages])
    end
  end

  test "logs on unexpected nested params" do
    params = ActionController::Parameters.new({
      :book => { :pages => 65, :title => "Green Cats and where to find then." }
    })

    assert_logged("Unpermitted parameters: title") do
      params.permit(:book => [:pages])
    end
  end
end
