# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
# Rails.application.config.filter_parameters += %i[
#   passw secret token _key crypt salt certificate otp ssn
# ]

Rails.application.config.filter_parameters += [
  :passw, :secret, :token, :crypt, :salt, :certificate, :otp, :ssn,
  # Filter parameters including '_key', except when they are exactly 'file_key'
  # or file_keys. They are used in controllers to identify files on the
  # storage and we want to see those in the logs.
  /^(?!file_keys?$).*_key/
]
