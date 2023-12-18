# frozen_string_literal: true

class Api::V1::ApiController < ActionController::API
  before_action :authenticate_request
  attr_reader :current_user

  protected

  def authenticate_request
    token = (request.headers['Authorization'] || '').split(' ').last
    begin
      @decoded = JWT.decode(token, Rails.application.secret_key_base, true, algorithm: 'HS256')
      @current_user = User.find(@decoded[0]['user_id'])
    rescue ActiveRecord::RecordNotFound => e
      render json: { errors: e.message }, status: :unauthorized
    rescue JWT::DecodeError => e
      render json: { errors: e.message }, status: :unauthorized
    end
  end
end
