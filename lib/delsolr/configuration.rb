module DelSolr
  class Client
    class Configuration
      attr_accessor :server, :port    

      def initialize(server, port)
        @server = server
        @port = port.to_i
      end

    end
  end
end
