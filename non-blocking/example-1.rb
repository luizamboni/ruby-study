require 'httparty'
require 'benchmark'
require 'memory_profiler'
require 'net/http'
require 'byebug'
require 'logger'

@logger = Logger.new(STDOUT)
@logger.level = Logger::DEBUG

def log string
  # puts string
end
n = 50

class NoBlockingClient
  def initialize()
    @io_n = 0
    @sockets = []
    @event_loop = Thread.new {

      # while this instance exist
      while self do
        log "event loop init"
        sockets = @sockets.map { |entry| entry[:socket] }

        sleep(0.3)
        log" sockets to monitoring: #{sockets.size} "
        if sockets.any? 
          read_sockets, w_sockets = IO.select( sockets, sockets, sockets, 0.5)
          log "sockets ready: #{ read_sockets.size}"
          read_sockets.each do |s|
            current = @sockets.find{ |s2| s2[:socket].__id__ == s.__id__ }
            callback = current[:callback]
            current[:result] = callback.call(s.read, current)
            s.close
            log "#{current[:n]} RESOLVED"

            @sockets.delete(current)
          end
        end
        log "event loop end"
      end
    }
  end

  def request url=nil, callback = -> (content, current = nil) { puts content }

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
    @io_n += 1
    puts @io_n
    current = { socket: s, callback: callback, result: nil, n: @io_n  }
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


url = "http://localhost:3000"

count = 0
client = NoBlockingClient.new

callback =  -> (content, current) { 
  # puts content
  puts "current: #{current[:n]}"
  count += 1
  puts "callbacks called #{count} for item #{current[:n]}"
  current[:n]
}

results = (1..200).map{ |i| client.request(url, callback) }
# debugger

puts results.map(&:resume)
puts "\n\n"


sleep 1

