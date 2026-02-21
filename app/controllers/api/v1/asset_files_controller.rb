# frozen_string_literal: true

# Handles asset file uploads to S3.
# All uploads go through the API — the server streams the file and uploads
# to S3 synchronously, using multipart upload for large files.
class Api::V1::AssetFilesController < Api::V1::ApiController
  # Files >= this size use S3 multipart upload instead of a single PUT.
  MULTIPART_UPLOAD_THRESHOLD = 100.megabytes

  # POST /api/v1/asset_files/download_urls
  def download_urls
    response_data = file_keys.map do |key|
      [key, storage.generate_presigned_url(key)]
    end
    render json: response_data
  end

  # PUT /api/v1/asset_files/upload/*file_key
  def upload
    temp_file = Tempfile.new(['upload', File.extname(file_key)])

    begin
      IO.copy_stream(request.body_stream || request.body, temp_file)
      temp_file.rewind

      if request.content_length.to_i >= MULTIPART_UPLOAD_THRESHOLD
        storage.multipart_upload(file_key, temp_file)
      else
        storage.write_file(file_key, temp_file)
      end

      render json: { success: true }
    rescue StandardError => e
      Rails.logger.error "Upload failed for #{file_key}: #{e.message}"
      render json: { success: false, error: e.message }, status: :unprocessable_entity
    ensure
      temp_file.close
      temp_file.unlink
    end
  end

  # POST /api/v1/asset_files/delete_file
  def delete_file
    storage.delete_file(file_key)
    render json: { success: true }
  end

  # POST /api/v1/asset_files/file_info
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
