# frozen_string_literal: true

class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :users do |t|
      t.string :email
      t.string :password_digest
      t.string :refresh_token
      t.datetime :refresh_token_expires_at
      t.string :storage_bucket

      t.timestamps
    end
  end
end
