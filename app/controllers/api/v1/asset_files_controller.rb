# frozen_string_literal: true

# Handles asset file uploads to S3
# Files ≥4GB use API proxy with background S3 multipart upload
# Upload progress tracking requires Rails.cache (memory_store works, null_store doesn't)
class Api::V1::AssetFilesController < Api::V1::ApiController
  PROXY_UPLOAD_THRESHOLD = 4.gigabytes  # Files >= 4GB use API proxy with background S3 upload
  
  
  # POST /api/v1/asset_files/download_urls
  def download_urls
    response_data = file_keys.map do |file_key|
      [file_key, storage.generate_presigned_url(file_key)]
    end

    render json: response_data
  end

  def upload_url
    # Check if file size >= threshold
    # If so, return API proxy upload URL instead of S3 presigned URL
    file_size = params.require(:file_size).to_i

    if file_size >= PROXY_UPLOAD_THRESHOLD
      # For large files, use API proxy upload
      # Include auth token in URL since FileSystem.createUploadTask doesn't send headers
      token = request.headers['Authorization']&.split(' ')&.last
      proxy_url = "#{request.base_url}/api/v1/asset_files/upload_proxy/#{CGI.escape(file_key)}?token=#{token}"
      render json: { upload_url: proxy_url }
    else
      # For smaller files, use direct S3 upload
      render json: { upload_url: storage.generate_presigned_url(file_key, method: :put_object) }
    end
  end

  def upload_proxy
    # Accept file, respond immediately, upload to S3 in background
    temp_file = Tempfile.new(['upload', File.extname(file_key)])
    
    begin
      # Save upload to temp file
      input_stream = request.body_stream || request.body
      IO.copy_stream(input_stream, temp_file)
      temp_file.rewind
      
      # Initialize progress tracking
      Rails.cache.write("upload_progress:#{file_key}", {
        status: 'uploading',
        progress: 0
      }, expires_in: 1.hour)
      
      # Start background S3 upload
      file_key_for_thread = file_key
      storage_for_thread = storage
      
      Thread.new do
        begin
          result = storage_for_thread.multipart_upload(file_key_for_thread, temp_file) do |uploaded_parts, total_parts, bytes_uploaded|
            progress = (uploaded_parts.to_f / total_parts * 100).round
            Rails.cache.write("upload_progress:#{file_key_for_thread}", {
              status: 'uploading',
              progress: progress,
              uploaded_parts: uploaded_parts,
              total_parts: total_parts,
              bytes_uploaded: bytes_uploaded
            }, expires_in: 1.hour)
          end
          
          Rails.cache.write("upload_progress:#{file_key_for_thread}", {
            status: 'complete',
            progress: 100
          }, expires_in: 5.minutes)
          
          Rails.logger.info "Background S3 upload completed: #{file_key_for_thread} - #{result[:parts_count]} parts"
        rescue StandardError => e
          Rails.logger.error "Background upload failed: #{file_key_for_thread} - #{e.message}"
          Rails.cache.write("upload_progress:#{file_key_for_thread}", {
            status: 'failed',
            error: e.message
          }, expires_in: 5.minutes)
        ensure
          temp_file.close
          temp_file.unlink
        end
      end
      
      render json: { success: true, status: 'uploading' }
    rescue StandardError => e
      temp_file&.close
      temp_file&.unlink
      Rails.logger.error "Upload proxy failed: #{e.message}"
      render json: { success: false, error: e.message }, status: :unprocessable_entity
    end
  end

  def delete_file
    storage.delete_file(file_key)
    render json: { success: true }
  end

  def file_info
    info = storage.file_info(file_key)
    
    # Add background upload progress if available
    upload_progress = Rails.cache.read("upload_progress:#{file_key}")
    if upload_progress
      info[:upload_progress] = upload_progress
    end
    
    render json: info
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
