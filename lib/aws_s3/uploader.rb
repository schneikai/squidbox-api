module AwsS3
  class Uploader
    def initialize
      @resource = Aws::S3::Resource.new(AwsS3::CONFIG)
      @bucket = @resource.bucket(AwsS3::BUCKET_NAME)
    end

    def initialize_upload(key)
      obj = @bucket.object(key)
      presigned_url = obj.presigned_url(:put, acl: 'public-read')
      public_url = obj.public_url
      {
        presigned_url: presigned_url,
        public_url: public_url
      }
    end
  end
end
