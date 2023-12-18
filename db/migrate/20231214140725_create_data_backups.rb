# frozen_string_literal: true

class CreateDataBackups < ActiveRecord::Migration[7.1]
  def change
    create_table :data_backups do |t|
      t.references :user, null: false, foreign_key: true
      t.string :file_name, null: false
      t.string :backup_file_name, null: false

      t.timestamps
    end
  end
end
