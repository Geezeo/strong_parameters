require 'test_helper'

class TransitionalFilterTest < ActiveSupport::TestCase
  def setup
    @old_parameter_filter = ActionController::Parameters::Filter.parameter_filter
    ActionController::Parameters::Filter.action_on_unpermitted_parameters = :log
    ActionController::Parameters::Filter.parameter_filter = ActionController::Parameters::Filter::Transitional
  end

  def teardown
    ActionController::Parameters::Filter.action_on_unpermitted_parameters = false
    ActionController::Parameters::Filter.parameter_filter = @old_parameter_filter
  end

  test 'key: unknown keys are filtered out' do
    params = ActionController::Parameters.new(:id => '1234', :injected => 'injected')
    assert_logged "Unpermitted parameters: injected\n" do
      permitted = params.permit(:id)
      assert_equal 'injected', permitted[:injected]
    end
  end

  test 'key: arrays are filtered out' do
    [[], [1], ['1']].each do |array|
      params = ActionController::Parameters.new(:id => array)

      assert_logged "Unpermitted parameters: id\n" do
        permitted = params.permit(:id)
        assert_equal permitted[:id], array
      end

      %w(i f).each do |suffix|
        key = "foo(000#{suffix})"
        params = ActionController::Parameters.new(key => array)
        assert_logged "Unpermitted parameters: #{key}\n" do
          permitted = params.permit(:foo)
          assert_equal permitted[key], array
        end
      end
    end
  end

  test 'key: hashes are filtered out' do
    [{}, {:foo => 1}, {:foo => 'bar'}].each do |hash|
      params = ActionController::Parameters.new(:id => hash)

      assert_logged "Unpermitted parameters: id\n" do
        permitted = params.permit(:id)
        assert_equal hash.with_indifferent_access, permitted[:id]
      end

      %w(i f).each do |suffix|
        key = "foo(000#{suffix})"
        params = ActionController::Parameters.new(key => hash)

        assert_logged "Unpermitted parameters: #{key}\n" do
          permitted = params.permit(:foo)
          assert_equal hash.with_indifferent_access, permitted[key]
        end
      end
    end
  end

  test 'key: non-permitted scalar values are filtered out' do
    value = Object.new
    params = ActionController::Parameters.new(:id => value)
    assert_logged "Unpermitted parameters: id\n" do
      permitted = params.permit(:id)
      assert_equal value, permitted[:id]
    end

    %w(i f).each do |suffix|
      key = "foo(000#{suffix})"
      params = ActionController::Parameters.new(key => value)
      assert_logged "Unpermitted parameters: #{key}\n" do
        permitted = params.permit(:foo)
        assert_equal value, permitted[key]
      end
    end
  end

  test 'key to empty array: permitted scalar values do not pass' do
    ['foo', 1].each do |permitted_scalar|
      params = ActionController::Parameters.new(:id => permitted_scalar)
      assert_logged "Unpermitted parameters: id\n" do
        permitted = params.permit(:id => [])
        assert_equal permitted_scalar, permitted[:id]
      end
    end
  end

  test 'key to empty array: arrays of non-permitted scalar do not pass' do
    [[Object.new], [[]], [[1]], [{}], [{'id' => '1'}]].each do |non_permitted_scalar|
      params = ActionController::Parameters.new(:id => non_permitted_scalar)
      assert_logged "Unpermitted parameters: id\n" do
        permitted = params.permit(:id => [])
        assert_equal non_permitted_scalar, permitted[:id]
      end
    end
  end

  test "permitted nested parameters" do
    params = ActionController::Parameters.new({
      :book => {
        :title => "Romeo and Juliet",
        :authors => [{
          :name => "William Shakespeare",
          :born => "1564-04-26"
        }, {
          :name => "Christopher Marlowe"
        }, {
          :name => %w(malicious injected names)
        }],
        :details => {
          :pages => 200,
          :genre => "Tragedy"
        }
      },
      :magazine => "Mjallo!"
    })

    assert_logged "Unpermitted parameters: born\nUnpermitted parameters: name\nUnpermitted parameters: genre\nUnpermitted parameters: magazine\n" do
      permitted = params.permit :book => [ :title, { :authors => [ :name ] }, { :details => :pages } ]

      assert_equal %w(malicious injected names), permitted[:book][:authors][2][:name]
      assert_equal "Mjallo!", permitted[:magazine]
      assert_equal "Tragedy", permitted[:book][:details][:genre]
      assert_equal "1564-04-26", permitted[:book][:authors][0][:born]
    end
  end

  test "nested array with strings that should be hashes" do
    params = ActionController::Parameters.new({
      :book => {
        :genres => ["Tragedy"]
      }
    })

    assert_logged "Unpermitted parameters: genres\n" do
      permitted = params.permit :book => { :genres => :type }
      assert_equal ['Tragedy'], permitted[:book][:genres]
    end
  end

  test "nested array with strings that should be hashes and additional values" do
    params = ActionController::Parameters.new({
      :book => {
        :title => "Romeo and Juliet",
        :genres => ["Tragedy"]
      }
    })

    assert_logged "Unpermitted parameters: genres\n" do
      permitted = params.permit :book => [ :title, { :genres => :type } ]
      assert_equal ["Tragedy"], permitted[:book][:genres]
    end
  end

  test "nested string that should be a hash" do
    params = ActionController::Parameters.new({
      :book => {
        :genre => "Tragedy"
      }
    })

    assert_logged "Unpermitted parameters: genre\n" do
      permitted = params.permit :book => { :genre => :type }
      assert_equal "Tragedy", permitted[:book][:genre]
    end
  end

  test "fields_for_style_nested_params" do
    params = ActionController::Parameters.new({
      :book => {
        :authors_attributes => {
          :'0' => { :name => %w(injected names)}
        }
      }
    })

    assert_logged "Unpermitted parameters: name\n" do
      permitted = params.permit :book => { :authors_attributes => [ :name ] }

      assert_equal({'name' => %w(injected names)},
          permitted[:book][:authors_attributes]['0'])
    end
  end

  test "fields_for_style_nested_params with negative numbers" do
    params = ActionController::Parameters.new({
      :book => {
        :authors_attributes => {
          :'-1' => { :name => 'William Shakespeare', :age_of_death => '52' },
        }
      }
    })

    assert_logged "Unpermitted parameters: age_of_death\n" do
      permitted = params.permit :book => { :authors_attributes => [:name] }
      assert_equal '52', permitted[:book][:authors_attributes]['-1'][:age_of_death]
    end
  end

  private

  def assert_filtered_out(params, key)
    assert !params.has_key?(key), "key #{key.inspect} has not been filtered out"
  end

  def assert_logged(message)
    old_logger = ActionController::Base.logger
    log = StringIO.new
    ActionController::Base.logger = Logger.new(log)

    begin
      yield

      log.rewind
      assert_match message, log.read
    ensure
      ActionController::Base.logger = old_logger
    end
  end
end
