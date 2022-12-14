class AuthenticationController < ApplicationController

#  attr_reader        :current_reader
  skip_before_action :authenticate_request
  skip_before_action :cors, :only => [:create_token,\
                                      :create_reader,\
				      :destroy_reader,\
				      :login_reader,\
                                      :logout_reader,\
                                      :logout_user]
  before_action      :allow_credentials, :only => [:authenticate]

    #La autenticacien de la request es la que ocupa, authenticate_request. Este método ofrece la autorización devolviendo loggedIn true al cliente AMP que usa el runtime AMP para permitir el acceso vía el componente amp-access a los readers de noticias
    #es el login de amp pages, pero se llama cuando la página se refresca. Eso significa que el token se regenera. El token anterior es almacenado como variable amp-access, y accesado por amp-list con cada request.
    #Para renovar el token se necesita ir a la base de datos.
    #Si lo que se quiere es evitar el acceso a la base de datos, el token no podrá guardarse tampoco.
    #Entonces, dónde puedo guardar el token? o generarlo a partir de rid u otra variable que no sea necesario leer de la base de datos. Se puede guardar como cookies, pero eso tampoco lo quiero.
    #O pedirle al usuario nuevamente los datos.
 
   #Ese es uno de los problemas. El token garantiza acceso estático por un período que no se puede modificar posteirmente sin invalidar el token. Entonces la soución es acortar la expiración del token y emitir token secundarios para aumentr el tiempo de sesión.
   #Lo otro, que es mi solución, es generar macarrones

  #Esto responde a authorization de la página amp-page, se le suministra el reader y el client_id. Responde con token y macarrón de autorización.
  #Esto se llama a cada rato. Y cada vez se genera un token y un macarrón

  def authenticate

    #Esto devuelve una respuesta que autoriza el acceso a elemntos del página amp. Se llama al comienzo pero se vuelve llamar cada vez que se piden datos dentro de un control de listas que usa una fuente de datos en amp-pages.
    #Aquí genero un macarrón nuevo con datos frescos sobre el circuito.
    #A lo que parece también se genera un token fresco, creo que eso ya no es necesario
    linea.info "En authenticate" 
    #Se genera un elemento de autenticación llamado token, el que se envía como auth_token en la respuesta de request
#    command      = AuthenticateReader.call(params[:rid]) ##Antes, el token se generaba aquí. Ahora se debe llamar a un servicio de autenticación. Aunque el primero podría hacer de falback.
    auth_token = AccessKey.new(params[:rid]).get #El access key debe asignado en el login y gu
    #command      = AuthenticateReader.call(params[:rid])
    #if command.success?
     # token = command.result
    ##end
    autorizacion = AutorizaMacarron.call(params[:rid])

    if auth_token #Si existe un token de autorizacioń, eso será suficiente paraautorizar las requests. El token se genera para un id de usuario Reader, También se obtiene la autorizaicón del macarrón asociado a este id de usuario. Eso es suficiente par declarar que el usuario puede usar lo que quiera y que está logado.

      linea.info "Se tiene un token"
      linea.info auth_token
     #loggedIn y access son variables de AMP paga que permiten cosas
      @current_reader = current_reader
      if @current_reader
        linea.info "Current Readers #{@current_suer}"
        respuesta = { macarron_de_autorizacion: autorizacion.result, auth_token: auth_token, 'loggedIn' => @current_reader.logged_in, 'access' => true , 'current_reader' => @current_reader.id, 'subscriber' => (not (current_reader.nil?)) }
      else
        respuesta = { macarron_de_autorizacion: autorizacion.result, auth_token: false, 'loggedIn' => false, 'access' => false, 'subscriber' => (not (@current_reader.nil?)) }
      end
      render json: respuesta
    else
      linea.error "AuthenticateReader tiene un Resultado Negativo"
      render json: { auth_token: false, 'loggedIn' => false, 'access' => false, 'subscriber' => false }
    end
  end



  def login_reader #es el login de amp pages
    linea.info "En login_reader de authentication"
    command = LoginReader.call(params[:rid])
 
    if command.success?
      linea.info "Comando Exitoso"
      if command.result
        linea.info "Comando con resultado"
        @url = params[:return] + "#success=true"
        redirect_to @url
      else
        linea.error "Comando sin buen resultado"
        @url = params[:return] 
        redirect_to @url
#render json: { error: command.errors }, status: :unauthorized
      end
    else
      linea.error "Comando no Exitoso"
      @url = params[:return] 
      redirect_to @url

#     render json: { error: command.errors }, status: :unauthorized
    end
  end


  #Crea un token para un reader amp, de esta forma, las requests de lists de la página de marketing en fronten tendrán un mecanismo de autenticación y autorización sin que el servidor backend deba crear cookies.
  def create_token
    linea.info "Create Token"
    raise NotReaderId unless params[:rid]
    raise NotClientId unless params[:clientId]
    command = CreateToken.call(params[:rid], params[:clientId])
    if command.success?
      @url = params[:return] + "#success=true"
      redirect_to @url #La redirección es exigida por AMP para acceder con loggedIn autorizado por AMP runtime, Si no se va a los servidores de google amp, el status loggedIn no se activará en ese momento, sino cuando se refresque la página AMP.
      #Cualquier acceso con refresco llamará al request de authenticación establecido en el componente amp-access de AMP, que está conectado al método authenticate_api_request. Que a su vez verifica que el token generado aquí venga en los parámetros de request (?param_1= &param2)
      # El token se puede decodifica para extraer el id del reader, lo que permitirá a los comandos de autenticación encontrar al email del usuario para enviarlo al cliente de publicidad amp. El reader es hijo del usuario.
      #
    else
      redirect_to params[:return]
    end

  end



  def create_reader #es el sign_up de amp pages

    command = CreateReader.call( params[:rid])

    if command.success?
      response.headers['AMP-Access-Control-Allow-Source-Origin'] = request.headers['Origin']
      response.headers['Access-Control-Allow-Origin'] = request.headers['Origin']
      response.headers['Access-Control-Allow-Credentials'] = true
      response.headers['Access-Control-Expose-Headers'] = 'AMP-Access-Control-Allow-Source-Origin'

      @url = params[:return] + "#success=true"
      redirect_to @url
     # render json: { auth_token: command.result }
    else
      redirect_to params[:return]
#      render json: { error: command.errors }, status: :unauthorized
    end
  end




  def create_user #es el sign_up de amp pages

    command = CreateUser.call( params[:email], params[:password], params[:password_confirmation], params[:rid], params[:clientId])

    if command.success?
      response.headers['AMP-Access-Control-Allow-Source-Origin'] = request.headers['Origin']
      response.headers['Access-Control-Allow-Origin'] = request.headers['Origin']
      response.headers['Access-Control-Allow-Credentials'] = true
      response.headers['Access-Control-Expose-Headers'] = 'AMP-Access-Control-Allow-Source-Origin'

      @url = params[:return] + "#success=true"
      redirect_to @url
     # render json: { auth_token: command.result }
    else
      redirect_to params[:return]
#      render json: { error: command.errors }, status: :unauthorized
    end
  end

  def logout_reader
    linea.info "En acción logout_reader"
    command = LogoutReader.call( params[:rid])
    linea.info "Al voler de LogoutReader"
    if command.success?
      linea.info "El comando fue exitoso"
      @url = params[:return] + "#success=true"
      redirect_to @url
    else
      linea.error "El comando no fue exitoso"
      redirect_to params[:return]
    end

  end

  def logout_user
    linea.info "En acción logout_user"
    command = LogoutUser.call(params[:email], params[:password], params[:rid])

    if command.success?
      linea.info "Comando exitoso"
      @url = params[:return] + "#success=true" #el parametro return no pone la pagina amp para que apunte al servidor amp. Desde donde se devolverá a logout_done si sale bien
      redirect_to @url
     # render json: { auth_token: command.result }
    else
      linea.info "Comando no fue exitoso"
      redirect_to params[:return]
#      render json: { error: command.errors }, status: :unauthorized
    end
  end

  def destroy_reader #es el logout de amp pages
    command = DestroyReader.call(params[:rid])

    if command.success?
        @url = params[:return] + "#success=true"
        redirect_to @url 
    else
      redirect_to params[:return]
    end
  end

  def destroy_user #es el logout de amp pages
    command = DestroyUser.call(params[:rid])

    if command.success?
        @url = params[:return] + "#success=true"
        redirect_to @url and return
    else
      redirect_to params[:return]
    end
  end

  private

  def current_reader
    Auth.call(params).result
  end   

  def logout_done
    linea.info "En logout_done de authentication"
    response.headers['AMP-Access-Control-Allow-Source-Origin'] = @origen
    linea.info "Origen es #{@origen}"
    @return = params[:return_url]
    linea.info "Return es #{@return}"

    respond_to do |format|
      format.json { redirect_to @return }
    end
  end




end

