
class AwsS3MultipartUploader
  CONFIG = {
    access_key_id: Rails.application.credentials.dig(:aws, :access_key_id),
    secret_access_key: Rails.application.credentials.dig(:aws, :secret_access_key),
    region: "eu-west-1"
  }

  BUCKET_NAME = "u41od6cqgqfo"
  
  def initialize
    @resource = Aws::S3::Resource.new(CONFIG)
    @bucket = @resource.bucket(BUCKET_NAME)
  end

  def initialize_upload(identifier, filename)
    key = multipart_upload_filename(identifier, filename)
    obj = @bucket.object(key)

    params = {
      bucket: obj.bucket_name,
      prefix: key
    }

    upload_id = @resource.client.list_multipart_uploads(params).uploads.first&.upload_id

    if upload_id
      params = {
        bucket: obj.bucket_name,
        key: key,
        upload_id: upload_id
      }
      # :parts=>[#<struct Aws::S3::Types::Part part_number=1, last_modified=2022-06-20 14:49:59 UTC, etag="\"5ef3fb5f714c7f057123599d8804d2fb\"", size=3745314, checksum_crc32=nil, checksum_crc32c=nil, checksum_sha1=nil, checksum_sha256=nil>]
      parts = @resource.client.list_parts(params).parts.map do |part|
        {
          part_number: part.part_number,
          etag: part.etag,
          size: part.size
        }
      end
    end

    unless upload_id
      params = {
        bucket: obj.bucket_name,
        key: obj.key,
        acl: 'public-read'
      }
      upload_id = @resource.client.create_multipart_upload(params).upload_id
    end

    {
      upload_id: upload_id,
      parts: parts || [],
      key: key
    }
  end

  def prepare_upload_part(upload_id, key, part_number)
    obj = @bucket.object(key)
    presigned_url = obj.presigned_url(:upload_part, part_number: part_number, upload_id: upload_id)
    {
      presigned_url: presigned_url
    }
  end

  def finalize_upload(upload_id, key)
    obj = @bucket.object(key)

    params = {
      bucket: obj.bucket_name,
      key: key,
      upload_id: upload_id
    }

    # :parts=>[#<struct Aws::S3::Types::Part part_number=1, last_modified=2022-06-20 14:49:59 UTC, etag="\"5ef3fb5f714c7f057123599d8804d2fb\"", size=3745314, checksum_crc32=nil, checksum_crc32c=nil, checksum_sha1=nil, checksum_sha256=nil>]
    parts = @resource.client.list_parts(params).parts.map do |part|
      {
        part_number: part.part_number,
        etag: part.etag
      }
    end

    params = {
      bucket: obj.bucket_name,
      key: key,
      multipart_upload: {
        parts: parts
      },
      upload_id: upload_id
    }
    @resource.client.complete_multipart_upload(params)
    {
      public_url: obj.public_url
    }
  end

  private

  def delete(remote_file_location)
    @bucket.object(remote_file_location).delete
  end

  def delete_multipart_upload_file(identifier, filename)
    key = multipart_upload_filename(identifier, filename)
    delete key
  end

  def multipart_upload_filename(identifier, filename)
    "#{identifier}-upload#{File.extname(filename).downcase}"
  end
end
