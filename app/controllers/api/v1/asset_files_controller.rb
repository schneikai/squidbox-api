# frozen_string_literal: true

# Handles asset file uploads to S3.
# All uploads go through the API — the server streams the file and uploads
# to S3 synchronously, using multipart upload for large files.
class Api::V1::AssetFilesController < Api::V1::ApiController
  # Files >= this size use S3 multipart upload instead of a single PUT.
  # Threshold is set above the chunk size (100MB) so multipart only kicks in
  # for files that will actually be split into multiple parts.
  MULTIPART_UPLOAD_THRESHOLD = 200.megabytes

  # POST /api/v1/asset_files/download_urls
  def download_urls
    response_data = file_keys.map do |key|
      [key, storage.generate_presigned_url(key)]
    end
    render json: response_data
  end

  # PUT /api/v1/asset_files/upload/*file_key
  def upload
    stream = request.body_stream || request.body
    content_length = request.content_length.to_i

    if content_length >= MULTIPART_UPLOAD_THRESHOLD
      storage.multipart_upload(file_key, stream)
    else
      storage.write_file(file_key, stream, content_length:)
    end

    render json: { success: true }
  rescue StandardError => e
    Rails.logger.error "Upload failed for #{file_key}: #{e.message}"
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end

  # POST /api/v1/asset_files/delete_file
  def delete_file
    storage.delete_file(file_key)
    render json: { success: true }
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
