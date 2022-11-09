Gem::Specification.new do |s|
  s.name        = 'csv-indexer'
  s.version     = '1.0.1'
  s.date        = '2022-11-08'
  s.summary     = "CSV Indexer makes it simple the indexation and searching in lasge CSV files."
  s.description = "CSV Indexer makes it simple the indexation and searching in lasge CSV files. It is not as robust as Lucence, but it is simple and cost-effective. May index files with millions of rows and find specific rows in matter of seconds. Find documentation here: https://github.com/leandrosardi/csv-indexer."
  s.authors     = ["Leandro Daniel Sardi"]
  s.email       = 'leandro.sardi@expandedventure.com'
  s.files       = [
    'lib/csv-indexer.rb',
  ]
  s.homepage    = 'https://github.com/leandrosardi/csv-indexer'
  s.license     = 'MIT'
  s.add_runtime_dependency 'csv', '~> 3.2.2', '>= 3.2.2'
  s.add_runtime_dependency 'simple_cloud_logging', '~> 1.2.2', '>= 1.2.2'
end