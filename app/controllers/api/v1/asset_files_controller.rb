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
    # Check if file size >= 4GB (4,294,967,296 bytes)
    # If so, return API proxy upload URL instead of S3 presigned URL
    file_size = params.require(:file_size).to_i
    four_gb = 4 * 1024 * 1024 * 1024

    if file_size >= four_gb
      # For large files, use API proxy upload
      proxy_url = "#{request.base_url}/api/v1/asset_files/upload_proxy/#{CGI.escape(file_key)}"
      render json: { upload_url: proxy_url }
    else
      # For smaller files, use direct S3 upload
      render json: { upload_url: storage.generate_presigned_url(file_key, method: :put_object) }
    end
  end

  def upload_proxy
    # Stream the uploaded file directly to S3 using multipart upload
    # This bypasses the 4GB PUT request limit by using multipart upload
    result = storage.multipart_upload(file_key, request.body)
    render json: { success: true, parts_count: result[:parts_count] }
  rescue StandardError => e
    render json: { success: false, error: e.message }, status: :unprocessable_entity
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
