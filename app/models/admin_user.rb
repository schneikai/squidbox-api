class AdminUser < ApplicationRecord
  has_secure_password

  def self.ransackable_attributes(auth_object = nil)
    ["id", "email", "created_at", "updated_at"]
  end
end
