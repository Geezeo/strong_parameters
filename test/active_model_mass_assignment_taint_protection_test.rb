require 'test_helper'

class Person
  include ActiveModel::MassAssignmentSecurity
  include ActiveModel::ForbiddenAttributesProtection

  public :sanitize_for_mass_assignment
end

class ActiveModelMassUpdateProtectionTest < ActiveSupport::TestCase
  test "forbidden attributes cannot be used for mass updating" do
    assert_raises(ActiveModel::ForbiddenAttributes) do
      Person.new.sanitize_for_mass_assignment(ActionController::Parameters.new(:a => "b"))
    end
  end

  test "forbidden attributes can be logged when used for mass updating" do
    begin
      ActiveModel::ForbiddenAttributesProtection.action_on_forbidden_attributes = :log
      assert_logged "Forbidden attributes\n" do
        Person.new.sanitize_for_mass_assignment(ActionController::Parameters.new(:a => "b"))
      end
    ensure
      ActiveModel::ForbiddenAttributesProtection.action_on_forbidden_attributes = :raise
    end
  end

  test "permitted attributes can be used for mass updating" do
    assert_nothing_raised do
      assert_equal({ "a" => "b" },
        Person.new.sanitize_for_mass_assignment(ActionController::Parameters.new(:a => "b").permit(:a)))
    end
  end

  test "regular attributes should still be allowed" do
    assert_nothing_raised do
      assert_equal({ :a => "b" },
        Person.new.sanitize_for_mass_assignment(:a => "b"))
    end
  end
end
