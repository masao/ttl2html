Gem::Specification.new do |s|
  s.name        = 'ttl2html'
  s.version     = '2.2.0'
  s.date        = '2025-06-07'
  s.summary     = "ttl2html"
  s.description = "Static site generator for RDF/Turtle"
  s.authors     = ["Masao Takaku"]
  s.email       = 'tmasao@acm.org'
  s.files       = [
    "lib/ttl2html.rb", "lib/ttl2html/version.rb", "lib/ttl2html/template.rb",
    "lib/ttl2html/util.rb",
    "lib/xlsx2shape.rb",
  ]
  s.files       += Dir["templates/*", "locales/*"]
  s.executables += ["ttl2html", "xlsx2shape", "catttl"]
  s.homepage    = 'https://github.com/masao/ttl2html'
  s.license     = 'MIT'
  s.add_dependency "nokogiri"
  s.add_dependency "rdf-turtle"
  s.add_dependency "roo", "~> 2"
  s.add_dependency "csv"
  s.add_dependency "i18n"
  s.add_dependency "ruby-progressbar"
  s.add_dependency "actionview"
  s.add_dependency "getoptlong"
  s.add_dependency "parallel"
  s.add_development_dependency "rspec"
  s.add_development_dependency "rake"
  s.add_development_dependency "capybara"
end
