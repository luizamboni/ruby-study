require 'httparty'
require 'benchmark'
require 'memory_profiler'
require 'net/http'
require 'byebug'


n = 50

class NoBlockingClient
  def initialize() 
    @sockets = []
    @event_loop = Thread.new {

      # while this instance exist
      while self do
        puts @sockets
        sockets = @sockets.map { |entry| entry[:socket] }

        # puts "before"
        sleep(0.3)
        # puts "list of sockets: ", sockets
        if sockets.any? 
          read_sockets, w_sockets = IO.select( sockets, sockets, sockets, 1)
          puts "sockers ready:" , read_sockets
          read_sockets.each do |s|
            current = @sockets.find{ |s2| s2[:socket].__id__ == s.__id__ }
            callback = current[:callback]
            current[:result] = callback.call(s.read)
            s.close
            @sockets.delete(s)
          end
        end
        # puts "after"
      end
    }
  end

  def request url=nil, callback = -> (content) { puts content }

    break_line = "\r\n"

    uri = URI(url)
    request_line = "GET / HTTP/1.0#{break_line}"
    headers = [
      "Content-Length:0",
      "Host:#{uri.hostname}"
    ].join(break_line)
    
    puts [ uri.hostname , uri.port ].join ":"
    
    s = TCPSocket.new uri.hostname, uri.port

    request = [ 
      request_line,
      headers,
      break_line,
      break_line
    ].join("")

    s.write request

    current = { socket: s, callback: callback, result: nil }
    @sockets << current

    Fiber.new {
      loop do
        if s.closed? 
          break
        end
      end

      current[:result]
    }
  end

end


def example 
  url = "http://google.com"

  count = 0
  client = NoBlockingClient.new


  results = [
    client.request(url),
    client.request(url),
    client.request(url),
    client.request(url),
    client.request(url),
    client.request(url)
  ]

  puts results.map(&:resume)

  puts Thread.list.count
end

example()
sleep 2
puts Thread.list.count


# client.request(url, -> (content) {
  
#   puts content
#   count += 1
#   puts count
# })


