Gem::Specification.new do |s|
  s.name = "delsolr"
  s.version = "0.1.5"
  s.authors = ["Ben VandenBos"]
  s.date = %q{2009-11-02}
  s.description = "Ruby wrapper for Lucene Solr"
  s.files = [
    "License.txt",
    "README.txt",
    "lib/delsolr.rb",
    "lib/delsolr/configuration.rb",
    "lib/delsolr/extensions.rb",
    "lib/delsolr/query_builder.rb",
    "lib/delsolr/response.rb",
    "lib/delsolr/document.rb"
  ]
  s.homepage = %q{http://github.com/avvo/delsolr}
  s.require_paths = ['lib']
  s.summary = %q{DelSolr is a light weight ruby wrapper for solr.  It's
      intention is to expose the full power of solr queries while keeping the
      interface as ruby-esque as possible.}
  s.test_files = [
    "test/test_client.rb",
    "test/test_helper.rb",
    "test/test_query_builder.rb",
    "test/test_response.rb"
  ]
  s.add_development_dependency(%q{mocha}, [">= 0.9.0"])
end
