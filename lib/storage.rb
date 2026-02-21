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

  def write_file(key, stream, content_length:)
    s3_client.put_object(bucket: @bucket_name, key:, body: stream, content_length:)
  end

  def delete_file(key)
    s3_client.delete_object(bucket: @bucket_name, key:)
  end

  # Streams a large file to S3 using multipart upload (100MB chunks).
  # Reads directly from the IO stream without buffering to disk.
  # @param key [String] The S3 object key
  # @param stream [IO] The IO stream to read from (e.g. request.body_stream)
  # @param chunk_size [Integer] Size of each part in bytes (default 100MB)
  def multipart_upload(key, stream, chunk_size: 100 * 1024 * 1024)
    upload_id = s3_client.create_multipart_upload(bucket: @bucket_name, key:).upload_id
    parts = []
    part_number = 1

    begin
      while (chunk = stream.read(chunk_size))
        response = s3_client.upload_part(
          bucket: @bucket_name,
          key:,
          part_number:,
          upload_id:,
          body: chunk
        )
        parts << { etag: response.etag, part_number: }
        part_number += 1
      end

      s3_client.complete_multipart_upload(
        bucket: @bucket_name,
        key:,
        upload_id:,
        multipart_upload: { parts: }
      )
    rescue StandardError => e
      s3_client.abort_multipart_upload(bucket: @bucket_name, key:, upload_id:)
      raise
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
