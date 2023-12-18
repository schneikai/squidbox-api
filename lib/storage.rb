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

  private

  def s3_client
    @s3_client ||= Aws::S3::Client.new(
      region: 'eu-west-1',
      access_key_id: Rails.application.credentials.dig(:aws, :access_key_id),
      secret_access_key: Rails.application.credentials.dig(:aws, :secret_access_key)
    )
  end
end
