# frozen_string_literal: true

# Data controller is responsible for handling JSON data for assets,
# albums, and posts.
class Api::V1::DataController < Api::V1::ApiController
  # GET /api/v1/data
  # Returns download URLs for the JSON data files.
  # This is used in the APP to download the data files.
  def index
    storage = Storage.new(current_user.storage_bucket)
    parts = {}

    ['assets.json', 'albums.json', 'posts.json'].each do |file_key|
      parts[file_key] = storage.generate_presigned_url(file_key) if storage.file_exists?(file_key)
    end

    render json: parts
  end

  private

  def data_params
    params.require(:data)
  end
end
