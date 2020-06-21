%w(
	redic
	magic
	json
	time
	cgi
).each &method(:require)

# The namespace for WebVac.  See the README.
module WebVac
	# Config object, intended to be used as a singleton.
	class Config
		# The default config options.  See the README.
		Defaults = {
			redis_url: "redis://localhost:6379/0",

			server_path_strip: "/media",
			server_path_prepend: "/media/block/fse",

			venti_server: 'localhost',

			plan9bin: '/opt/plan9/bin',

			mime_substitutions: {
				'text/html' => 'text/plain',
			},
		}
		attr_accessor *Defaults.keys

		# The sorted list of places where we will look for config files
		# to load.
		ConfigPaths = [
			ENV['WEBVAC_CONFIG'],
			"./config/webvac.json",
			"#{ENV['HOME']}/.webvac.json",
			"/etc/webvac.json",
		].compact

		# Reads/parses config and instantiates an object
		def self.load
			f = ConfigPaths.find { |f| File.readable?(f) }
			cfg = if f
				JSON.parse File.read(f)
			else
				{}
			end
			new cfg
		end

		# Takes a config, replaces the defaults with it.
		# Will throw exceptions if you give it a bad config, you should probably
		# just call Config.load.
		def initialize cfg
			Defaults.each { |k,v|
				send("#{k}=", v)
			}
			cfg.each { |k,v|
				send("#{k}=", v)
			}
		end

		def path_fixup path
			@_path_rx ||= /^#{Regexp.escape(server_path_strip)}/
			path.sub(@_path_rx, server_path_prepend)
		end
	end

	# Stateless-ish client for venti.
	# I completely punted on implementing a venti client, so it just calls
	# the vac/unvac binaries.  Does the job!
	class Vac
		attr_reader :config

		# Takes an instance of Config.
		def initialize cfg
			@config = cfg
		end

		def save! fn
			contents = File.read(fn)
			pi, po = IO.pipe
			io = IO.popen(
				{'venti' => config.venti_server},
				["#{config.plan9bin}/vac", '-i', File.basename(fn)],
				in: pi
			).tap { |io| Thread.new { Process.wait(io.pid) } }
			po.write contents
			po.close
			io.read.chomp.sub(/^vac:/, '')
		end

		def load_io vac
			unless /^vac:[a-f0-9]{40}$/.match(vac)
				raise ArgumentError, "#{vac.inspect} not a vac score?"
			end
			IO.popen(
				{'venti' => config.venti_server},
				["#{config.plan9bin}/unvac", '-c', vac]
			).tap { |io| Thread.new { Process.wait(io.pid) } }			
		end

		def load! vac
			load_io(vac).read
		end
	end

	# Sits in front of Redis (just Redis right now), and handles the mapping
	# of vac hashes to pathnames, as well as the metadata (in JSON and in the
	# form of HTTP headers, which allows HEAD requests to be cheap).  Also does
	# some of the bookkeeping necessary for that, like the interaction with
	# libmagic.
	#
	# Relatively threadsafe, but maintains one Redis connection per active
	# thread (created on demand).
	class Table
		attr_reader :config

		# Takes an instance of Config.
		def initialize cfg
			@config = cfg
		end

		# Takes a filename, returns the filename's metadata.  Stateless-ish.
		def fn2md f
			s = File.stat(f)
			m = {
				'Content-Type' => Magic.guess_file_mime_type(f),
				'Content-Length' => s.size.to_s,
				'Last-Modified' => s.mtime.rfc822,
			} rescue nil
		end

		def meta_save! fn, sc
			md = fn2md(fn)
			return unless md
			redis.call 'HSET', 'score2md', sc, md.to_json
		end

		def metadata score
			# Overall, doesn't really matter if this fails.
			JSON.parse(
				redis.call('HGET', 'score2md', score.sub(/^vac:/, ''))
			) rescue nil
		end

		def rec_score! fn, sc
			redis.call 'HSET', 'path2score', fn, sc
		end

		def redis
			Thread.current[:webvac_redis] ||= Redic.new(config.redis_url)
		end

		def path2score p
			r = redis.call 'HGET', 'path2score', p
			return "vac:#{r}" if r
		end

		def guess_mime contents
			Magic.guess_string_mime_type(contents)
		end
	end
end
