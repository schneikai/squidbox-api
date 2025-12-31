# frozen_string_literal: true

class Api::V1::ApiController < ActionController::API
  before_action :authenticate_request
  attr_reader :current_user

  protected

  def authenticate_request
    # Try to get token from Authorization header first, then from query parameter
    token = request.headers['Authorization']&.split(' ')&.last || params[:token]
    
    if token.blank?
      render json: { errors: 'No authentication token provided' }, status: :unauthorized
      return
    end
    
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
