module AwsS3
  CONFIG = {
    access_key_id: Rails.application.credentials.dig(:aws, :access_key_id),
    secret_access_key: Rails.application.credentials.dig(:aws, :secret_access_key),
    region: "eu-west-1"
  }

  BUCKET_NAME = "u41od6cqgqfo"
end
