class ContactosController < ApplicationController

  skip_before_action :authenticate_request, only: [:verify, :create]
  before_action :set_contacto, only: [:show, :update, :destroy]
  before_action :allow_credentials, only: [:create,:verify]


  def verify
    expires_in 0.minutes, :public => false
    atributos = contacto_params.except(:__amp_source_origin).merge!(:password => params[:clientId], :password_confirmation => params[:clientId])
    cliente   = Client.find_or_create_by(:clientId => contacto_params[:clientId])
    reader    = cliente.reader
    atributos = contacto_params.except(:__amp_source_origin,:clientId,:rid).merge!(:password => params[:clientId], :password_confirmation => params[:clientId])
    contacto  = User.new(atributos)

    if contacto.valid?
       render json: {"resultado" => "Ok"}, status: :ok
    else
      render json: {"objeto" => "User.verify en contactos_controlle","verifyErrors" => contacto.errors.messages.map{|e| {:name =>e[0], :message => e[1].pop}}}, status: :not_found
    end

  end


  # POST /contactos
  # POST /contactos.json
  def create

    #Esta acción crea un cliente y lo asocia a un reader id existente

    #Garantiza que se tenga un cliente con el clientId recibido.
    #Este principio se basa en que el propietario actual del dispositio (móvil o deskotp) con el amp_client_id especificado tiene prioridad sobre cualqueir otro propietario anterior 
    #
    #Se usa un cliente y muchos readers: un reader por dispositivo, dominio, y brower
    #Se crea o se autoriza un cliente existente
    #Se crea o se autoriza un reader id existente
    #Se establece un lazo entre ellos
    #Cuando se borre la cuenta en ampo, lo que se borra es el reader, de esta forma los datos de proceso quedan enlazados  a los datos del cliente

    #Para borrar al cliente se debe ir al backend a una ventana especial
    #No creada aún

    #El registro de cliente es esencial para individualizar los presupuestos eletricos que ha pedido cliente. El Reader id es  el usuario de los microservicios, son livianos y tienen  limites con macarrones, o el usuario los puede borrar.

    #Cuando google registra un amp_cliente_id  se puede saber si el email ya está en backend y eso se usa para relacionar clientes con readers.

    #Cuando el usuario borrar un reader, dejará de tener acceso a todos los micros servicios desde el dispositivo, browser y dominio. 
    #Es posible que alguien use un email de un cliente existente, eso generará un acceso a un microservicio que no corresponde, por eso es necesario enviar un token o url con token para autorizar que se genere un nuevo reader. Mientras eso no esté desarrollado se pedierá un login y con el login se crearé el reader.
    #Si no existe el cliente, no hay ese problema, pues se generará un cliente con la password ingresad y además de generará un nuevo reader  
    atributos = contacto_params.except(:__amp_source_origin,:clientId,:rid)
    contacto = User.new(atributos)



    if contacto.valid? and contacto_params[:clientId]
      contacto.save
      reader  = Reader.find_or_create_by(:rid => params[:rid])
      cliente = Client.find_or_create_by(:reader_id => reader.id, :clientId => contacto_params[:clientId])
      reader.update(:user_id => contacto.id)
      render json: {"resultado" => contacto.name }, status: :ok 
    else
      render json: {"objeto" => "Contacto.create en contactos_controller #{contacto.email}","verifyErrors" => contacto.errors.messages.map{|e| {:name =>e[0], :message => e[1].pop}}}, status: :not_found
    end

  end

  private

    # Use callbacks to share common setup or constraints between actions.
    def set_contacto
      @contacto = User.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def contacto_params
      params.permit(:name, :email, :fono, :clientId,:password,:password_confirmation)
    end

end
