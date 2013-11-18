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

require 'delsolr/extensions'

module DelSolr
  autoload :Client, 'delsolr/client'
  autoload :Document, 'delsolr/document'
end