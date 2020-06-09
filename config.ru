%w(
	watts
	webvac
).each &method(:require)

Encoding.default_external = Encoding::BINARY

module WebVac
	class R < Watts::Resource
		# This is a stupid feature.
		# Fortunes lifted shamelessly from http://quotes.cat-v.org/programming/
		Fortunes = <<-EOFORTUNES.gsub(/\t+/, '').split(/\n+/)
			There are two ways of constructing a software design: One way is to make it so simple that there are obviously no deficiencies and the other way is to make it so complicated that there are no obvious deficiencies.
			When in doubt, use brute force.
			Deleted code is debugged code.
			Debugging is twice as hard as writing the code in the first place. Therefore, if you write the code as cleverly as possible, you are, by definition, not smart enough to debug it.
			The most effective debugging tool is still careful thought, coupled with judiciously placed print statements.
			Controlling complexity is the essence of computer programming.
			UNIX was not designed to stop its users from doing stupid things, as that would also stop them from doing clever things.
			Beware of those who say that their software does not suck, for they are either fools or liars.
			Unix is simple. It just takes a genius to understand its simplicity.
			If you want to go somewhere, goto is the best way to get there.
			I object to doing things that computers can do.
			A good way to have good ideas is by being unoriginal.
			a program is like a poem: you cannot write a poem without writing it.
		EOFORTUNES

		def headers t, path, score, contents
			name = (request.params['name'] || File.basename(path)).
				gsub('"', "'")
			{
				'Content-Disposition' => "filename=\"#{name}\"",
				'Fortune' => Fortunes.sample,
			}.merge!(t.metadata(score) || {}).tap { |h|
				if contents
					h['Content-Type'] ||= t.guess_mime(contents) rescue nil
					h['Content-Length'] ||= contents.bytesize.to_s
				end
			}
		end
	end

	class Root < R
		auto_head
		get {
			"++++++++++++[>+++++++++<-]>.+++.---."
		}
	end

	class Serv < R
		# We can cheat a little with closures because there's just one "real"
		# endpoint.  No need to memoize.

		config = Config.load
		vac = Vac.new config
		tab = Table.new config

		head { |*|
			p = config.path_fixup(CGI.unescape(env['REQUEST_PATH']))
			s = tab.path2score p
			return [404, {}, ["404 Not found\nNo such path: #{p}\n"]] unless s
			[200, headers(tab, p, s, nil), []]
		}
		get { |*|
			p = config.path_fixup(CGI.unescape(env['REQUEST_PATH']))
			s = tab.path2score p
			return [404, {}, ["404 Not found\nNo such path: #{p}\n"]] unless s
			ct = Time.parse(env['HTTP_IF_MODIFIED_SINCE']) rescue nil
			if ct && ct.to_i > 0
				hs = headers(tab, p, s, nil)
				mt = Time.parse(hs['Last-Modified']) rescue nil
				return [304, hs, []] if mt && mt > ct
			end
			contents = vac.load! s
			hs = headers(tab, p, s, contents)
			[200, headers(tab, p, s, contents), [contents]]
		}
	end

	class App < Watts::App
		resource('/', Root) {
			resource(:filename, Serv)
			resource(['media', :l1], Serv) { resource(:l2, Serv) }
		}
	end
end

run WebVac::App.new
