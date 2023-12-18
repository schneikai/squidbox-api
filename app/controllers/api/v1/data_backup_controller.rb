# frozen_string_literal: true

# Data controller is responsible for handling JSON data for assets,
# albums, and posts.
class Api::V1::DataBackupController < Api::V1::ApiController
  # POST /api/v1/data_backup/initialize_backup
  # data_files: ['assets.json', 'albums.json', 'posts.json']
  def init
    # ['assets.json', 'albums.json', 'posts.json']

    data_files = params.require(:data_files)
    storage = Storage.new(current_user.storage_bucket)
    timestamp = Time.now.utc
    formatted_timestamp = timestamp.strftime('%Y%m%d%H%M%S')

    backup_files = data_files.map do |file_key|
      backup_file_key = "#{file_key}.#{formatted_timestamp}"
      upload_file_key = "#{file_key}.#{formatted_timestamp}.tmp"
      { file_key:, backup_file_key:, upload_file_key:,
        upload_url: storage.generate_presigned_url(upload_file_key, method: :put_object) }
    end

    render json: backup_files
  end

  # POST /api/v1/data_backup/finalize_backup
  # backup_urls: This contains the same data that was sent in the init request.
  # TODO: Add some code to delete old backups. Maybe keep the last 10 backups or something.
  def finalize
    backup_urls = params.require(:backup_files)
    storage = Storage.new(current_user.storage_bucket)

    backup_urls.each do |backup_url|
      file_key = backup_url.require(:file_key)
      backup_file_key = backup_url.require(:backup_file_key)
      upload_file_key = backup_url.require(:upload_file_key)

      storage.move_file(file_key, backup_file_key) if storage.file_exists?(file_key)

      storage.move_file(upload_file_key, file_key)
      DataBackup.create!(user: current_user, file_name: file_key, backup_file_name: backup_file_key)
    end

    cleanup_old_backups!
  end

  private

  def cleanup_old_backups!
    keep_backups = 25
    storage = Storage.new(current_user.storage_bucket)

    unique_file_names = DataBackup.where(user: current_user).pluck(:file_name).uniq
    unique_file_names.each do |file_name|
      DataBackup.where(user: current_user, file_name:)
                .order(created_at: :desc).offset(keep_backups).each do |backup|
        storage.delete_file(backup.backup_file_name)
        backup.destroy
      end
    end
  rescue StandardError => e
    Rails.logger.error("Error cleaning up old backups: #{e.message}")
  end
end
