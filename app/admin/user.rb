# frozen_string_literal: true

ActiveAdmin.register User do
  permit_params :email, :password, :password_confirmation, :storage_bucket

  index do
    selectable_column
    id_column
    column :email
    column :storage_bucket
    column :current_sign_in_at
    column :sign_in_count
    column :created_at
    actions
  end

  filter :id
  filter :email
  filter :created_at

  form do |f|
    f.inputs do
      f.input :email
      f.input :password
      f.input :password_confirmation
    end
    f.inputs do
      f.input :storage_bucket
    end
    f.actions
  end
end
