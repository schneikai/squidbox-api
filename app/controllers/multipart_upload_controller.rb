class MultipartUploadController < ApplicationController
  def init
    data = multipart_uploader.initialize_multipart_upload(params.fetch(:identifier), params.fetch(:filename))
    render json: data
  end

  def upload_part_url
    data = multipart_uploader.upload_part_url(params.fetch(:upload_id), params.fetch(:key),
                                           params.fetch(:part_number))
    render json: data
  end

  def finalize
    data = multipart_uploader.complete_multipart_upload(params.fetch(:upload_id), params.fetch(:key))
    render json: data
  end

  private

  def multipart_uploader
    @multipart_uploader ||= AwsS3MultipartUploader.new
  end
end
