# frozen_string_literal: true

class Api::V1::AssetFilesController < Api::V1::ApiController
  # POST /api/v1/asset_files/download_urls
  def download_urls
    response_data = file_keys.map do |file_key|
      [file_key, storage.generate_presigned_url(file_key)]
    end

    render json: response_data
  end

  def upload_url
    render json: { upload_url: storage.generate_presigned_url(file_key, method: :put_object) }
  end

  def delete_file
    storage.delete_file(file_key)
    render json: { success: true }
  end

  def file_info
    render json: storage.file_info(file_key)
  end

  private

  def file_key
    params.require(:file_key)
  end

  def file_keys
    params.require(:file_keys)
  end

  def storage
    @storage ||= Storage.new(current_user.storage_bucket)
  end
end
