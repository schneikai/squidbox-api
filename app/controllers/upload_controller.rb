class UploadController < ApplicationController
  def init
    data = uploader.initialize_upload(params.fetch(:filename))
    render json: data
  end

  private

  def uploader
    @uploader ||= AwsS3::Uploader.new
  end
end
