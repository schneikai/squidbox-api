# frozen_string_literal: true

class Api::V1::UserController < Api::V1::ApiController
  # GET /api/v1/user
  def index
    render json: {
      user: current_user.json_for_api_user
    }
  end
end
