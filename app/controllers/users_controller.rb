class UsersController < ApplicationController
  before_action :set_user

  skip_before_action :set_organization, :authorize_organization_access

  def show
    @organizations = @user.organizations.page(params[:page])
  end

  private

  def set_user
    @user = User.find(session[:user_id])
  end
end
