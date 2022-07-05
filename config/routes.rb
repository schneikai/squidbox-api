Rails.application.routes.draw do
  post 'multipart_upload/init', to: 'multipart_upload#init'
  post 'multipart_upload/upload_part_url', to: 'multipart_upload#upload_part_url'
  post 'multipart_upload/finalize', to: 'multipart_upload#finalize'

  root "application#index"
end
