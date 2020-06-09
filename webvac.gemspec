Gem::Specification.new { |s|
	s.platform = Gem::Platform::RUBY

	s.author = "Pete"
	s.email = "pete@debu.gs"
	s.files = Dir["{lib,doc,bin,ext,conf}/**/*"].delete_if {|f|
		/\/rdoc(\/|$)|\.gitignore$/i.match f
	} + %w(Rakefile config.ru)
	s.require_path = 'lib'
	s.has_rdoc = true
	s.extra_rdoc_files = (Dir['doc/*'] << 'README').select(&File.method(:file?))
	s.extensions << 'ext/extconf.rb' if File.exist? 'ext/extconf.rb'
	Dir['bin/*'].map(&File.method(:basename)).map(&s.executables.method(:<<))

	s.name = 'webvac'
	s.summary = "UGC management/backup using venti"
	s.homepage = "http://github.com/pete/#{s.name}"
	s.licenses = %w(AGPL-3.0) # For now, until I decide what to do.
	%w(
		redic
		watts
		json
		rainbows
		magic
	).each &s.method(:add_dependency)
	s.version = '0.1.3'
}
