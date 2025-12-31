# frozen_string_literal: true

class Storage
  attr_reader :bucket_name

  def initialize(bucket_name)
    @bucket_name = bucket_name
  end

  def generate_presigned_url(key, method: :get_object, expires_in: 1.hour.to_i)
    signer = Aws::S3::Presigner.new(client: s3_client)
    signer.presigned_url(method, bucket: @bucket_name, key:, expires_in:)
  end

  def file_info(key)
    info = s3_client.head_object(bucket: @bucket_name, key:)
    {
      exists: true,
      content_length: info.content_length,
      content_type: info.content_type,
      etag: info.etag,
      last_modified: info.last_modified
    }
  rescue Aws::S3::Errors::NotFound
    {
      exists: false
    }
  end

  def file_exists?(key)
    file_info(key)[:exists]
  end

  def move_file(from_key, to_key)
    s3_client.copy_object(bucket: @bucket_name, copy_source: "#{@bucket_name}/#{from_key}", key: to_key)
    s3_client.delete_object(bucket: @bucket_name, key: from_key)
  end

  def write_file(key, data)
    s3_client.put_object(bucket: @bucket_name, key:, body: data)
  end

  def delete_file(key)
    s3_client.delete_object(bucket: @bucket_name, key:)
  end

  # Performs multipart upload for large files
  # @param key [String] The S3 object key
  # @param io_stream [IO] The IO stream to read from
  # @param chunk_size [Integer] Size of each part in bytes (default 10MB)
  # @param progress_callback [Proc] Optional callback for progress updates
  def multipart_upload(key, io_stream, chunk_size: 10 * 1024 * 1024, &progress_callback)
    # Initialize multipart upload
    multipart_upload = s3_client.create_multipart_upload(
      bucket: @bucket_name,
      key: key
    )
    upload_id = multipart_upload.upload_id

    parts = []
    part_number = 1
    total_bytes = 0
    
    # Estimate total parts
    total_size = io_stream.size rescue nil
    estimated_parts = total_size ? (total_size.to_f / chunk_size).ceil : nil

    begin
      # Read and upload in chunks
      while (chunk = io_stream.read(chunk_size))
        chunk_size_bytes = chunk.bytesize
        total_bytes += chunk_size_bytes
        
        response = s3_client.upload_part(
          bucket: @bucket_name,
          key: key,
          part_number: part_number,
          upload_id: upload_id,
          body: chunk
        )

        parts << {
          etag: response.etag,
          part_number: part_number
        }
        
        # Call progress callback if provided
        if progress_callback && estimated_parts
          progress_callback.call(part_number, estimated_parts, total_bytes)
        end

        part_number += 1
      end

      # Complete the multipart upload
      s3_client.complete_multipart_upload(
        bucket: @bucket_name,
        key: key,
        upload_id: upload_id,
        multipart_upload: { parts: parts }
      )

      { success: true, parts_count: parts.length }
    rescue StandardError => e
      # Abort the multipart upload on error
      s3_client.abort_multipart_upload(
        bucket: @bucket_name,
        key: key,
        upload_id: upload_id
      )
      raise e
    end
  end

  private

  def s3_client
    @s3_client ||= Aws::S3::Client.new(
      region: 'eu-west-1',
      access_key_id: Rails.application.credentials.dig(:aws, :access_key_id),
      secret_access_key: Rails.application.credentials.dig(:aws, :secret_access_key)
    )
  end
end
