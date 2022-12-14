require 'rails_helper'

#Backend CoronaVirus
#Backend Autorizado de un MicroServicio
#Se usa un macarrón de autorización (se generar aqui) y un token local (el que debe ser generado en otro backend)
#Se prueba todo el flujo de identificación y autorización.
#Parte con la creación del token, luego se puede hacer login (sign_in). También se puede crear un cliente y hacer sign_in.
RSpec.describe 'Items API', :type => 'request' do

  # 
  #La authenticación busca que haya un token que al ser decodificado apunte a un reader_id.
  #En este ejemplo no interesa si hay un usuario o un cliente, solo interesa el reader, 
  #El reader y el token se crean al presionar el botón CREAR CUENTA
  #Y se eliminan al presionar el botón CERRAR Cuenta.
  #Entre ambos eventos, AMP consider que está logado, porque el authenticador en el backend se lo indica enviando loggedIn como respuesta tipo json
  let(:user)           { create(:user) }
  let(:reader)         { create(:reader, :user => user ) }  
  let(:coded_token)    { JsonWebToken.encode(reader: reader.as_json(:include => :user)) }
  #macarrón para autorizar en el backend_alectrica a un usuario que esé logado allá. El macarrón es verificado por un tercer bakend, el de autorización
  let(:valid_macarron) { macarron = Macarron.new( location: CFG[:backend_alectrica_url.to_s], identifier: 'w', key: ENV['SECRET_KEY_BASE'] ); 
                         macarron.add_first_party_caveat('LoggedIn = true') ; 
                         ms= macarron.serialize; 
                         return ms }
    
  let(:headers)        {{ "Origin" => CFG[:help_coronavid_url.to_s]  }}
     
  let(:valid_params)   {{ :__amp_source_origin => CFG[:help_coronavid_url.to_s],\
                         :auth_token => coded_token,\
                         :macarron_de_autorizacion => valid_macarron }}

  let(:params_wrong_auth_token)  {{ :__amp_source_origin => CFG[:help_coronavid_url.to_s],\
				    :auth_token => "woring_auth_token" ,
                                    :macarron_de_autorizacion => valid_macarron
   }}
  let(:params_sin_auth_token)  {{ :__amp_source_origin => CFG[:help_coronavid_url.to_s] ,:macarron_de_autorizacion => valid_macarron   }}


  #Estos son datos de contenido que serán ofrecidos al cliente
  let!(:todo)         { create(:todo)                                  }
  let!(:items)        { create_list(:item, 20, todo_id: todo.id)       }
  let(:todo_id)       { todo.id                                        }
  let(:id)            { items.first.id                                 }

  if Ch::Check.malo(:herokuapp_autorizador)

    let (:access_key)        { double('AccessKey') }
    let (:access_key_class)  { class_double('AccessKey').as_stubbed_const(:transfer_nested_constants => true) }
    let (:verificador)       { double('RemoteVerifyMacarron') }
    let (:verificador_class) { class_double('RemoteVerifyMacarron').as_stubbed_const(:transfer_nested_constants => true) }
    let (:verificador) { double('RemoteVerifyMacarron') }
    let (:verificador_class) { class_double('RemoteVerifyMacarron').as_stubbed_const(:transfer_nested_constants => true) }
    let (:access_key) { double('AccessKey') }
    let (:access_key_class) { class_double('AccessKey').as_stubbed_const(:transfer_nested_constants => true) }
    before {
      allow(access_key).to receive(:get).and_return('eyii')
      allow(access_key_class).to receive(:new).with('amprid').and_return(access_key)
      allow(verificador_class).to receive(:new).with(valid_macarron).and_return(verificador)
      allow(verificador).to receive(:get).and_return(true)
      allow(verificador).to receive(:get_result).and_return(true)
    }
  end


  describe 'Revisión del token' do
    context "Cuando genere un token válido en rspec" do
      it "Debería tener un usuario" do
        expect(JsonWebToken.decode(coded_token)['reader']['user']['name'].inspect).to eq(user.name.to_json)
      end
    end
  end

  #Test Suite for Get /todos/:todo_id/items
  #Index
  describe 'GET /todos/:todo_id/items' do
    #make HTTP get request before each example
    context 'Cuando auth_token no se ha enviado en los params' do
      before { 
        get "/todos/#{todo_id}/items", params: params_sin_auth_token, headers: headers
      }
      
      it 'informa que No Existe Token' do
	expect(response.body).to match(/NotAuthTokenPresent/)
      end
    end

    context 'Cuando auth_token es envíado en los params' do
      before { 
	get "/todos/#{todo_id}/items", params: valid_params, headers: headers
      }

      context ',pero está no apunta a un reader en la base de datos' do
	before{
          reader.destroy
          get "/todos/#{todo_id}/items", params: params_wrong_auth_token, headers: headers
	}
	it 'informa NotReader' do
          expect(response.body).to match(/NotReader/)
	end
      end

      context 'y existe ToDo' do
	it 'No debiera generar un error' do
	  expect{response}.not_to raise_error
        end
	it 'Debe Devolver el Código 200' do
	  expect(response).to have_http_status(200)
	end
	it 'Debe Devolver todo los registros ToDo' do
	  expect(json.size).to eq(20)
	end
      end

      context ', pero no existe ToDo' do
	let(:todo_id) { 0 }
	it 'Debe Devolver Código 404' do
	  expect(response).to have_http_status(404)
	end
	it 'Debe indicar un mensaje Not Found' do
	  expect(response.body).to match(/Couldn't find Todo/)
	end
      end
    end
  end

  #Test suite for GET /todos/:todo_id/items/:id'
  #Show
  describe 'GET /todos/:todo_id/items/:id' do
    before { get "/todos/#{todo_id}/items/#{id}", params: valid_params, headers: headers }
    context "Cuando los parámetros son válidos" do
      context 'when todo item exists' do

	it 'returns status code 200' do
	  expect(response).to have_http_status(200)
	end
	it 'returns then item' do
	  expect(json['id']).to eq(id)
	end

      end

      context 'when todo item does not exists' do
	let(:id) { 0 }

	it 'return status code 404' do
	  expect(response).to have_http_status(404)
	end

	it 'return a not found message' do
	  expect(response.body).to match(/Couldn't find Item/)
	end
      end
    end
  end

  #Test suite for POST /todos/:todo_id/items'
  #create
  describe 'POST /todos/:todo_id/items' do
   let(:valid_attributes)    {{"name" => "algo", 
                               :done => true, 
                               :__amp_source_origin => CFG[:help_coronavid_url.to_s],
                               :auth_token => coded_token,
                               :macarron_de_autorizacion => valid_macarron }}
   let(:invalid_attributes)  {{"name" => "",
                               :done => true, 
                               :__amp_source_origin => CFG[:help_coronavid_url.to_s], 
                               :auth_token => coded_token,
                               :macarron_de_autorizacion => valid_macarron }}


#   let( :valid_attributes ) {{"name" => "algo", :done => true,:__amp_source_origin => 'https://help.coronavid.cl', :auth_token => coded_token}}

    context "Cuando haya un token válido"  do

      context "y la solicitud sea válida" do
	before { post "/todos/#{todo_id}/items", params: valid_attributes, headers: headers }

	it "Devuelve un código 200" do
	  expect(response).to have_http_status(200)
	end

	it "Devuelve un carácter de nueva línea" do
	  expect(json['name']).to match(/algo/)
	end

      end

      context ", pero la solicitud no sea válida" do
	before { post "/todos/#{todo_id}/items", params: invalid_attributes, headers: headers }
	
	it "Devuelve un código 422" do
	  expect(response).to have_http_status(422)
	end

	it "Devuelve un Mensage de Error de Validación" do
	  expect(response.body).to match(/La validación falló: Name no puede estar en blanco/)
	end

      end
    end
  end

  #Test suite for PUT /todos/:todo_id/items/:id'
  #update
  describe 'PUT /todos/:todo_id/items/:id' do
    let(:user)          {  create(:user) }
    let(:reader)        {  create(:reader ,:user => user) }
    let(:coded_token)    { JsonWebToken.encode(reader: reader.as_json(:include => :user)) }


    let(:valid_attributes) {{ :name => "Nome",
                              :__amp_source_origin => CFG[:help_coronavid_url.to_s], 
                              :auth_token => coded_token, 
                              :macarron_de_autorizacion => valid_macarron }}

    before { 
      put "/todos/#{todo_id}/items/#{id}",  params: valid_attributes, :headers => headers
    }

    context "cuando el registro no existe" do
      let(:id) { 0 }

      it "Devuelve Código 404" do
        expect(response).to have_http_status(404)
      end

      it "Devuelve Mensaje Not Found" do
	expect(response.body).to match(/Couldn't find Item/)
      end

    end

    context "Cuando el eegistro existe" do

      it "Lo actualiza" do
	updated_item = Item.find(id)
	expect(updated_item.name).to match(/Nome/)
      end

      it "No devuelve nada en el cuerpo del mensaje" do
        expect(response.body).to be_empty
      end

      it "Devuelve un código 204" do
	expect(response).to have_http_status(204)
      end

    end
  end

  #Test suite for DELETE /todos/item/:id
  #delete
  describe 'DELETE /todos/item/id' do
    before {
      delete "/todos/#{todo_id}/items/#{id}", params: valid_params, headers: headers
    }

    it 'debe devolver 204' do
      expect(response).to have_http_status(204)      
    end

    it 'debe eliminar el record' do
      deleted_exists =  Item.exists?(id) 
      expect(deleted_exists).to eq(false)
    end

  end

  #Test suite integrando
  context "items con authenticación" do
    let(:return_params)  {{:rid => "amprid", :return => CFG[:authentication_endpoint_alectrico_url.to_s] } }
    let(:retorno)        { CFG[:authentication_endpoint_alectrico_url.to_s]  }  
    let(:success_return) {CFG[:retorno_exitoso_alectrico_url.to_s] }
    let(:headers)       {{ "Origin" => CFG[:help_coronavid_url.to_s]  }}

    describe 'GET /create_token' do

      before {
	get "/create_token", params: {:rid => "amprid", :clientId => "clientId", :return => CFG[:authentication_endpoint_alectrico_url.to_s]}
      }

      it "to be redirect to retorno" do
        expect(response.body).to redirect_to(CFG[:retorno_exitoso_alectrico_url.to_s])      end

    end
    describe 'GET /authenticate with wrong Origin header' do
      before {
        get "/create_token", params: {:rid => "amprid", :clientId => "clientId", :return => CFG[:authentication_endpoint_alectrico_url.to_s]}
        #Authenticate crea otro token para comunicarse con el AS
        get "/authenticate", params: {:rid => "amprid", :__amp_source_origin => CFG[:help_coronavid_url.to_s] }, headers: {'Origin' => "https://help.domain_no_autorizado.cl"}
      }
      it 'no devuelve token' do 
        expect(json['auth_token']).to be_nil
      end
    end

    describe 'GET /authenticate after get_token' do
      before {
        get "/create_token", params: {:rid => "amprid", :clientId => "clientId", :return => CFG[:authentication_endpoint_alectrico_url.to_s]}
        #Authenticate crea otro token para comunicarse con el AS
	get "/authenticate", params: {:rid => "amprid", :__amp_source_origin => CFG[:help_coronavid_url.to_s] }, headers: {'Origin' => CFG[:help_coronavid_url.to_s]}
      }

      it 'return' do 
        expect(json['auth_token']).to match(/ey/)
      end

    end

    describe 'GET /contactos/create' do
      before {
        get "/create_token", params: {:rid => "amprid", :clientId => "clientId", :return => CFG[:authentication_endpoint_alectrico_url.to_s]}
        #Authenticate crea otro token para comunicarse con el AS
        get "/authenticate", params: {:rid => "amprid", :__amp_source_origin => CFG[:help_coronavid_url.to_s] }, headers: {'Origin' => CFG[:help_coronavid_url.to_s]}
	post "/contactos/create", params: {:rid => "amprid", :clientId => "clientId",:name => "Nombre", :email => "email@example.com", :fono => '987654321', :password => "123456",:password_confirmation => "123456", :__amp_source_origin => CFG[:help_coronavid_url.to_s]}, headers: {'Origin' => CFG[:help_coronavid_url.to_s]}
      } 

      it 'return code 200'  do
        expect(response).to have_http_status(200)
      end

      it 'return nada' do
	expect(json['resultado']).to match(/Nombre/)
      end

    end

    describe 'GET /sign_in' do
      before {
        get "/create_token", params: {:rid => "amprid", :clientId => "clientId", :return => CFG[:authentication_endpoint_alectrico_url.to_s]}
        get "/authenticate", params: {:rid => "amprid", :__amp_source_origin => CFG[:help_coronavid_url.to_s] }, headers: {'Origin' => CFG[:help_coronavid_url.to_s]}
        post "/contactos/create", params: {:rid => "amprid", :clientId => "clientId",:name => "Nombre", :email => "email@example.com", :fono => '987654321', :password => "123456",:__amp_source_origin => CFG[:help_coronavid_url.to_s]}, headers: {'Origin' => CFG[:help_coronavid_url.to_s]}
        get  "/sign_in", params: {:rid => "amprid" , :return => retorno}
      }   

      it 'return code 302'  do  
        expect(response).to have_http_status(302)
      end 

      it "to be redirect to retorno" do
        expect(response.body).to redirect_to(CFG[:retorno_exitoso_alectrico_url.to_s])
      end

    end 

    describe 'GET /authenticate despues de crear cliente' do
      before {

        get "/create_token",\
	params: {:rid => "amprid",\
	  :clientId => "clientId",\
	  :return => CFG[:authentication_endpoint_alectrico_url.to_s]}

        #Authenticate crea otro token para comunicarse con el AS
        get "/authenticate",\
	  params: {:rid => "amprid",\
	    :__amp_source_origin => CFG[:help_coronavid_url.to_s] },\
	    headers: {'Origin' => CFG[:help_coronavid_url.to_s]}

        post "/contactos/create",\
	  params: {:rid => "amprid",\
	  :clientId => "clientId",\
	  :name => "Nombre",\
	  :email => "email@example.com",\
	  :fono => '987654321',\
	  :password => "123456",\
	  :__amp_source_origin => CFG[:help_coronavid_url.to_s]},\
	  headers: {'Origin' => CFG[:help_coronavid_url.to_s]}

        get  "/sign_in",\
	  params: {:rid => "amprid" ,\
	  :return => retorno}

        #Authenticate crea otro token para comunicarse con el AS
        get "/authenticate",\
	  params: {:rid => "amprid",\
	  :__amp_source_origin => CFG[:help_coronavid_url.to_s] },\
	  headers: {'Origin' => CFG[:help_coronavid_url.to_s]}
      }

      it 'return code 200'  do
        expect(response).to have_http_status(200)
      end

      it "to be loggedIn" do
        expect(json['loggedIn']).to eq(true)
      end

    end

    describe 'GET /authenticate a pesar de nocrear cliente' do
      before {
        get "/create_token",\
          params: {:rid => "amprid", :clientId => "clientId",\
          :return => CFG[:authentication_endpoint_alectrico_url.to_s]}

        #Authenticate crea otro token para comunicarse con el AS
        get "/authenticate",\
	  params: {:rid => "amprid",\
	  :__amp_source_origin => CFG[:help_coronavid_url.to_s] },\
	  headers: {'Origin' => CFG[:help_coronavid_url.to_s]}

        get  "/sign_in",\
	  params: {:rid => "amprid" ,\
	  :return => retorno}

        get "/authenticate",\
	  params: {:rid => "amprid",\
	  :__amp_source_origin => CFG[:help_coronavid_url.to_s] },\
	  headers: {'Origin' => CFG[:help_coronavid_url.to_s]}
      }

      it 'return code 200'  do
        expect(response).to have_http_status(200)
      end

      it "to be loggedIn" do
        expect(json['loggedIn']).to eq(true) #No se loga aunque no se haya creado el cliente. Debido a que se usa el reader para logar
      end

    end

    describe 'GET /authenticate a pesar de nocrear token ni cliente' do
      before {
        get "/authenticate",\
	  params: {:rid => "amprid",\
	  :__amp_source_origin => CFG[:help_coronavid_url.to_s] },\
	  headers: {'Origin' => CFG[:help_coronavid_url.to_s]}

        get  "/sign_in",\
	  params: {:rid => "amprid" , :return => retorno}

        #Authenticate crea otro token para comunicarse con el AS
        get "/authenticate",\
	  params: {:rid => "amprid",\
	  :__amp_source_origin => CFG[:help_coronavid_url.to_s] },\
	  headers: {'Origin' => CFG[:help_coronavid_url.to_s]}
      }

      it 'return code 200'  do
        expect(response).to have_http_status(200)
      end

      it "to be loggedIn" do
        expect(json['loggedIn']).to eq(false) #no debe logarse si no se ha creado el token, o más bien el reader que responde al token
      end

    end



    describe 'GET /authenticate a pesar de nocrear token ni cliente ni authenticate' do
      before {
        get  "/sign_in", params: {:rid => "amprid" , :return => retorno}
        get "/authenticate", params: {:rid => "amprid",\
				      :__amp_source_origin => CFG[:help_coronavid_url.to_s] },\
				      headers: {'Origin' => CFG[:help_coronavid_url.to_s]}
      }

      it 'return code 200'  do
        expect(response).to have_http_status(200)
      end

      it "to be loggedIn" do
        expect(json['loggedIn']).to eq(false) #La razón fundamental es que no se ha creado el token
      end

    end


    describe 'GET /authenticate a pesar de nocrear token ni cliente ni authenticate, pero con otro reader'  do

      if Ch::Check.malo(:herokuapp_autorizador)

          let (:access_key)        { double('AccessKey') }
          let (:access_key_class)  { class_double('AccessKey').as_stubbed_const(:transfer_nested_constants => true) }
          let (:verificador)       { double('RemoteVerifyMacarron') }
          let (:verificador_class) { class_double('RemoteVerifyMacarron').as_stubbed_const(:transfer_nested_constants => true) }
          let (:verificador) { double('RemoteVerifyMacarron') }
          let (:verificador_class) { class_double('RemoteVerifyMacarron').as_stubbed_const(:transfer_nested_constants => true) }
          let (:access_key) { double('AccessKey') }
          let (:access_key_class) { class_double('AccessKey').as_stubbed_const(:transfer_nested_constants => true) }
          before {
            allow(access_key).to receive(:get).and_return('eyii')

            allow(verificador_class).to receive(:new).with(valid_macarron).and_return(verificador)
            allow(verificador).to receive(:get).and_return(true)
            allow(verificador).to receive(:get_result).and_return(true)
          }

      end

      before {
        allow(access_key_class).to receive(:new).with('amprid2').and_return(access_key)
        otro_reader_existente = Reader.create!(:rid => "amprid2")

        get  "/sign_in", params: {:rid => "amprid2" , :return => retorno} if Ch::Check.malo(:herokuapp_autorizador)


        #Authenticate crea otro token para comunicarse con el AS
        allow(access_key_class).to receive(:new).with('amprid1').and_return(access_key) if Ch::Check.malo(:herokuapp_autorizador)

        get "/authenticate", params: {:rid => "amprid1",\
                                      :__amp_source_origin => CFG[:help_coronavid_url.to_s] },\
                                      headers: {'Origin' => CFG[:help_coronavid_url.to_s]}
      }


      it 'return code 200'  do
        expect(response).to have_http_status(200)
      end

      it "to be loggedIn" do
        expect(json['loggedIn']).to eq(false) #No se debe logar si el reader no existe.
      end

    end


    describe 'GET /authenticate a pesar de nocrear token ni cliente ni authenticate, pero con otro reader, y sin sign_in previo' do

  if Ch::Check.malo(:herokuapp_autorizador)

    let (:access_key)        { double('AccessKey') }
    let (:access_key_class)  { class_double('AccessKey').as_stubbed_const(:transfer_nested_constants => true) }
    let (:verificador)       { double('RemoteVerifyMacarron') }
    let (:verificador_class) { class_double('RemoteVerifyMacarron').as_stubbed_const(:transfer_nested_constants => true) }
    let (:verificador) { double('RemoteVerifyMacarron') }
    let (:verificador_class) { class_double('RemoteVerifyMacarron').as_stubbed_const(:transfer_nested_constants => true) }
    let (:access_key) { double('AccessKey') }
    let (:access_key_class) { class_double('AccessKey').as_stubbed_const(:transfer_nested_constants => true) }
    before {
      allow(access_key).to receive(:get).and_return('eyii')
      allow(access_key_class).to receive(:new).with('amprid2').and_return(access_key)
      allow(verificador_class).to receive(:new).with(valid_macarron).and_return(verificador)
      allow(verificador).to receive(:get).and_return(true)
      allow(verificador).to receive(:get_result).and_return(true)
    }
  end


      before {
        #Authenticate crea otro token para comunicarse con el AS
        get "/authenticate", params: {:rid => "amprid2", :__amp_source_origin => CFG[:help_coronavid_url.to_s] }, headers: {'Origin' => CFG[:help_coronavid_url.to_s]}
      }

      it 'return code 200'  do
        expect(response).to have_http_status(200)
      end

      it "to be loggedIn out" do
        expect(json['loggedIn']).to eq(false) #No se acepta autenticación si el usuario no existe
      end

    end


    describe 'GET /destroy_reader' do
      before {
        get "/create_token", params: {:rid => "amprid",\
				      :clientId => "clientId",\
				      :return => CFG[:authentication_endpoint_alectrico_url.to_s]}

        #Authenticate crea otro token para comunicarse con el AS
        get "/authenticate", params: {:rid => "amprid",\
				      :__amp_source_origin => CFG[:help_coronavid_url.to_s] },\
				      headers: {'Origin' => CFG[:help_coronavid_url.to_s]}

        post "/contactos/create",\
	  params: {:rid => "amprid",\
	   :clientId => "clientId",\
	   :name => "Nombre",\
	   :email => "email@example.com",\
	   :fono => '987654321', :password => "123456",\
	   :__amp_source_origin => CFG[:help_coronavid_url.to_s]},\
	   headers: {'Origin' => CFG[:help_coronavid_url.to_s]}

        get "/sign_in", params: {:rid => "amprid" , :return => retorno}

        get "/authenticate", params: {:rid => "amprid",\
				      :__amp_source_origin => CFG[:help_coronavid_url.to_s] },\
				      headers: {'Origin' => CFG[:help_coronavid_url.to_s]}

        get "/destroy_reader", params: {:rid => "amprid",:return => retorno }

      }

       it 'return code 302'  do
         expect(response).to have_http_status(302)
       end

       it "to be redirect to retorno" do
         expect(response.body).to\
	   redirect_to(CFG[:retorno_exitoso_alectrico_url.to_s])
       end

       it "destroy readr" do
         expect(Reader.count).to eq(0)
       end

    end

    describe "Todo el proceso" do
      before {
	#Esta es la integración de entrada
	#reader = create(:reader)
	#coded_token =JsonWebToken.encode(:reader_id => reader.id)

	get "/create_token", params: {:rid => "amprid",\
			       :clientId => "clientId",\
			       :return => retorno} 
        #Create token, crea un token para guardar el puntero a un reader. Para ello se debe crear antes el reader, el que quedará también indizado por rid. Tambíén se creará un cliente especificando su clientId
        #Authenticate crea otro token para comunicarse con el AS
        get "/authenticate", params: {:rid => "amprid",\
				      :__amp_source_origin => CFG[:help_coronavid_url.to_s] },\
				      headers: {'Origin' => CFG[:help_coronavid_url.to_s]}
	#Atuthenticate usa el amprid para encontrar al reader y si existe lo considera válido,pero igual genera un token para guardar el puntero al reader

	post "/contactos/create", params: {:rid => "amprid",\
				    :clientId => "clientId",\
				    :name => "Nombre",\
				    :email => "email@example.com",\
				    :fono => '987654321',\
				    :password => "123456",\
				    :__amp_source_origin => CFG[:help_coronavid_url.to_s]},\
				    :headers => headers

	#Encrypta es el botón submit de contactos create. El cual crea un usario nuevo y le asigna el reader actual (el cual se encuentra con amprid). También se intenta juntar al reader con el cliente (el que rresponde al indice clientId). En general hay una tríada user-reader-client
	get  "/sign_in", params: {:rid => "amprid" , :return => retorno}
	#El método de login usa el identificador de reader para buscarlo en la base de datos, si lo encuentra le calcula el token para guardar e lpuntero reader.id

        get "/authenticate", params: {:rid => "amprid",\
				      :__amp_source_origin => CFG[:help_coronavid_url.to_s] },\
				      headers: {'Origin' => CFG[:help_coronavid_url.to_s]}
	#Finalmente authenticate ahora puede buscar al reader en la base de datos usando el puntero rid. Si lo encuentra, lo considera válido y genera un token para apuntar al reader. 
	#También averigua si token generado en la etapa previa permite encontrar el puntero del reader y por ende verificar que está en la base de datos.
	#Con esto puede emular un helper current_reader, cuya existencia se usa para decretar que es está en estado logado o loggedIn
	#Es importante saber que se devuelve el auth_token para que se pueda emplear en los comandos de contenido y poder authorizar cada request solo en base al token encriptado
	get "/destroy_reader", params: {:rid => "amprid",:return => retorno }

        #Authenticate crea otro token para comunicarse con el AS
        get "/authenticate", params: {:rid => "amprid",\
				      :__amp_source_origin => CFG[:help_coronavid_url.to_s] },\
				      headers: {'Origin' => CFG[:help_coronavid_url.to_s]}
     }

     it 'loggedIn=false' do
       expect(json['loggedIn']).to eq(false)
     end

    end
  end
end
