Rails.application.routes.draw do
  post 'multipart_upload/init', to: 'multipart_upload#init'
  post 'multipart_upload/prepare_upload_part', to: 'multipart_upload#prepare_upload_part'
  post 'multipart_upload/finalize', to: 'multipart_upload#finalize'

  root "application#index"
end
