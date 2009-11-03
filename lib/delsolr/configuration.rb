module DelSolr
  class Client
    class Configuration
      attr_accessor :server, :port, :timeout, :path

      def initialize(server, port, timeout = nil, path = nil)
        @server = server
        @port = port.to_i
        @timeout = timeout || 120
        @path = path || '/solr'
      end

    end
  end
end
