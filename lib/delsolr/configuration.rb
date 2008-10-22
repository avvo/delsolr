module DelSolr
  class Client
    class Configuration
      attr_accessor :server, :port, :timeout

      def initialize(server, port, timeout = 120)
        @server = server
        @port = port.to_i
        @timeout = timeout || 120
      end

    end
  end
end
