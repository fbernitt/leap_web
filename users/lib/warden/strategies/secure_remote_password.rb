module Warden
  module Strategies
    class SecureRemotePassword < Warden::Strategies::Base

      def valid?
        handshake? || authentication?
      end

      def authenticate!
        if authentication?
          validate!
        else  # handshake
          initialize!
        end
      end

      protected

      def handshake?
        params['A'] && params['login']
      end

      def authentication?
        params['client_auth'] && session[:handshake]
      end

      def validate!
        client = session[:handshake].authenticate(params['client_auth'].hex)
        client ?
          success!(User.find_by_login(client.username)) :
          fail!(:password => "wrong_password")
      end

      def initialize!
        if user = User.find_by_login(id)
          client = SRP::Client.new user.username,
            :verifier => user.verifier,
            :salt => user.salt
          session[:handshake] = SRP::Session.new(client, params['A'].hex)
          custom! json_response(session[:handshake])
        else
          fail! :login => "user_not_found"
        end
      end

      def json_response(object)
        [ 200,
          {"Content-Type" => "application/json; charset=utf-8"},
          [object.to_json]
        ]
      end

      def id
        params["id"] || params["login"]
      end
    end
  end
  Warden::Strategies.add :secure_remote_password,
    Warden::Strategies::SecureRemotePassword

end


