Gem::Specification.new do |s|
  s.name = "delsolr"
  s.version = "0.3.4pre1"
  s.authors = ["Ben VandenBos"]
  s.date = %q{2009-11-02}
  s.description = "Ruby wrapper for Lucene Solr"
  s.homepage = %q{http://github.com/avvo/delsolr}
  s.summary = %q{DelSolr is a light weight ruby wrapper for solr.  It's
      intention is to expose the full power of solr queries while keeping the
      interface as ruby-esque as possible.}

  s.files = Dir["{app,config,db,lib}/**/*"] + ["License.txt", "Rakefile", "README.rdoc"]
  s.test_files = Dir.glob('test/*_test.rb')

  s.add_dependency("mocha")
  s.add_dependency("faraday", ["~> 0.9.0"])
  s.add_dependency("json")

  s.add_development_dependency("test-unit")
  s.add_development_dependency("mocha", [">= 0.9.0"])
  s.add_development_dependency("rake", ["0.9.2"])
end
