# frozen_string_literal: true

class ApplicationController < ActionController::Base
  protected

  def current_admin_user
    @current_admin_user ||= AdminUser.find(session[:admin_user_id]) if session[:admin_user_id]
  end

  def current_admin_user?
    current_admin_user.present?
  end

  helper_method :current_admin_user?

  def authenticate_admin_user!
    redirect_to admin_new_session_path unless session[:admin_user_id].present?
  end
end
