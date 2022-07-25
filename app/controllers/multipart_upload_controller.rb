class MultipartUploadController < ApplicationController
  # TODO: Just send a filename here that we can use as the identifier/key
  # identifier and filename is confusing
  def init
    data = multipart_uploader.initialize_upload(params.fetch(:identifier), params.fetch(:filename))
    render json: data
  end

  def prepare_upload_part
    data = multipart_uploader.prepare_upload_part(params.fetch(:upload_id), params.fetch(:key),
                                           params.fetch(:part_number))
    render json: data
  end

  def finalize
    data = multipart_uploader.finalize_upload(params.fetch(:upload_id), params.fetch(:key))
    render json: data
  end

  private

  def multipart_uploader
    @multipart_uploader ||= AwsS3::MultipartUploader.new
  end
end
