class UsersController < ApplicationController
  include Linea
  skip_before_action :authenticate_request, only: :create



  # POST /users
  # POST /users.json
  def create

    name = ''
    'first_name last_name'.split.each do |a|
      linea.info a
      linea.info user_params[a.to_sym].inspect
      name += user_params[a].nil? ? '' : user_params[a]
    end

    name_json = { 'name' => name }

    token = CreateUser.call( name_json, user_params[:email], user_params[:password], user_params[:password_confirmation], params[:rid], params[:clientId])


    if token?
      json = {"resultado" => user.name }
      #render json: json, status: :ok 
      redirect_to C.admin_login, notice: json
    else
      json = {"objeto" => "User.create en users_controller #{user.email}","verifyErrors" => user.errors.messages.map{|e| {:name =>e[0], :message => e[1].pop}}}
      #render json: json, status: :not_found
      redirect_to C.admin_registro, notice: json
    end
    

  end

  private
  def user_params
    params.require(:user).permit(:password, :first_name, :last_name, :email, :password_confirmation)
  end

end