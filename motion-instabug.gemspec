# -*- encoding: utf-8 -*-

Version = '1.0.0'

Gem::Specification.new do |spec|
  spec.name = 'motion-instabug'
  spec.summary = 'Instabug integration for RubyMotion projects'
  spec.description = 'motion-instabug allows RubyMotion projects to easily embed the Instabug SDK and be submitted to the Instabug platform.'
  spec.author = 'Benjamin Michotte'
  spec.email = 'bmichotte@gmail.com'
  spec.version = Version

  files = []
  files << 'README.rdoc'
  files << 'LICENSE'
  files.concat(Dir.glob('lib/**/*.rb'))
  spec.files = files

  spec.add_dependency 'motion-cocoapods', '>= 1.4.1'
  spec.add_dependency 'motion-require', '>= 0.1'
end
