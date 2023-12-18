# frozen_string_literal: true

class Api::V1::AuthenticationController < Api::V1::ApiController
  skip_before_action :authenticate_request, only: %i[login refresh]

  TOKEN_EXPIRATION = 2.hours
  REFRESH_TOKEN_EXPIRATION = 1.year

  # POST /api/v1/auth/login
  def login
    user = User.find_by(email: params[:email])
    if user&.authenticate(params[:password])
      access_token = encode_token({ user_id: user.id })
      refresh_token = generate_refresh_token(user)

      render json: { access_token:, refresh_token:, user: user.json_for_api_user }
    else
      render json: { error: 'Invalid email or password' }, status: :unauthorized
    end
  end

  def refresh
    user = User.find_by(refresh_token: params[:refresh_token])

    if user&.refresh_token_expires_at && user.refresh_token_expires_at > Time.current
      new_access_token = encode_token({ user_id: user.id })
      new_refresh_token = generate_refresh_token(user)
      render json: { access_token: new_access_token, refresh_token: new_refresh_token }
    else
      render json: { error: 'Invalid or expired refresh token' }, status: :unauthorized
    end
  end

  def logout
    if current_user
      current_user.update!(refresh_token: nil, refresh_token_expires_at: nil)
      render json: { message: 'Logged out successfully' }, status: :ok
    else
      render json: { error: 'Not logged in' }, status: :unauthorized
    end
  end

  private

  def encode_token(payload)
    expiration = TOKEN_EXPIRATION.from_now.to_i
    payload[:exp] = expiration
    JWT.encode(payload, Rails.application.secret_key_base)
  end

  def generate_refresh_token(user)
    token = SecureRandom.hex(10)
    expiration_time = REFRESH_TOKEN_EXPIRATION.from_now
    user.update!(refresh_token: token, refresh_token_expires_at: expiration_time)
    token
  end
end
