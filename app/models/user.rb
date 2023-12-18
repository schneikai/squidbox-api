# frozen_string_literal: true

class User < ApplicationRecord
  has_secure_password

  def self.ransackable_attributes(_auth_object = nil)
    %w[id email created_at updated_at]
  end

  def json_for_api_user
    as_json(only: %i[id email])
  end
end
