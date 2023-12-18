# frozen_string_literal: true

class DataBackup < ApplicationRecord
  belongs_to :user

  validates :file_name, :backup_file_name, presence: true
end
