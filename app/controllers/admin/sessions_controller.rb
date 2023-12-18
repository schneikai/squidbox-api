class Admin::SessionsController < ApplicationController
  def new
    # debugger
  end

  def create
    user = AdminUser.find_by(email: params[:email])
    if user&.authenticate(params[:password])
      session[:admin_user_id] = user.id
      redirect_to admin_root_path, notice: 'Logged in successfully'
    else
      flash.now.alert = 'Email or password is invalid'
      render :new
    end
  end

  def destroy
    session[:admin_user_id] = nil
    redirect_to admin_new_session_path, notice: 'Logged out'
  end
end
