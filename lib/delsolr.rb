#
# DelSolr
#
# ben@avvo.com 9.1.2008
#
# see README.txt
#

require 'faraday'
require 'json'
require 'digest/md5'

require File.expand_path("../delsolr/extensions", __FILE__)

module DelSolr
  autoload :Client, 'delsolr/client'
  autoload :Document, 'delsolr/document'
end