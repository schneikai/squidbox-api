# frozen_string_literal: true

class GetFileCreatedAtFromDropboxFiles
  def call
    # Base directory containing the folders
    base_directory = '/Users/kai/Library/CloudStorage/Dropbox/DT Final/'

    # Collecting folder names (assuming they are like '001', '002', ...)
    folders = Dir.children(base_directory).select { |f| File.directory?(File.join(base_directory, f)) }

    # Creating the JSON structure
    oldest_files = folders.map do |folder|
      folder_path = File.join(base_directory, folder)
      oldest_file = oldest_file_creation_time(folder_path)

      # Skip if no files in folder
      next if oldest_file.nil?

      {
        folder:,
        createdAt: File.birthtime(oldest_file) # or File.mtime(oldest_file) if birthtime is not available
      }
    end.compact

    # Optionally, save to a file
    File.write('oldest_files.json', oldest_files.to_json)
  end

  # Function to find the oldest file in a directory
  def oldest_file_creation_time(directory)
    Dir.children(directory).map do |file|
      File.join(directory, file)
    end.select do |file|
      File.file?(file)
    end.min_by do |file|
      File.birthtime(file) # or File.mtime(file) if birthtime is not available
    end
  end
end
