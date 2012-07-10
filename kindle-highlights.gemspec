Gem::Specification.new do |s|
  s.name        = 'kindle-highlights'
  s.version     = '0.0.6'
  s.summary     = "Kindle highlights"
  s.description = "Until there is a Kindle API, this will suffice."
  s.authors     = ["Eric Farkas"]
  s.email       = 'eric@prudentiadigital.com'
  s.files       = ["lib/kindle-highlights.rb"]
  s.homepage    = 'https://github.com/speric/kindle-highlights'
 
  s.add_runtime_dependency 'mechanize', '>= 2.0.1'
end