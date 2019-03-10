require 'httparty'
require 'benchmark'
require 'memory_profiler'
require 'net/http'
require 'byebug'
require 'logger'
require 'fiber'

@logger = Logger.new(STDOUT)
@logger.level = Logger::DEBUG

def log string
  # puts string
end

n = 5

class NoBlockingClient
  def initialize()
    @io_n = 0
    @sockets = []
    @event_loop = Thread.new {

      # while this instance exist
      while self do
        log "event loop init"
        sockets = @sockets.map { |entry| entry[:socket] }

        log " sockets to monitoring: #{sockets.size} "

        if sockets.any? 
          read_sockets, write_sockets = IO.select( sockets, sockets, sockets, 0.3)
          log "sockets ready: #{read_sockets.size}"

          # write_sockets.each do |s|
          #   log "write socket #{s.__id__}"
          #   current = @sockets.find{ |s2| s2[:socket].__id__ == s.__id__ }
          #   s.write current[:write]
          #   s.close_write
          # end

          read_sockets.each do |s|
            log "read socket #{s.__id__}"

            current = @sockets.find{ |s2| s2[:socket].__id__ == s.__id__ }
            callback = current[:callback]

            content = s.read
            current[:duration] = ((Time.now.to_f - current[:init_time]) * 1000 ).round 3

            current[:result] = callback.call(content, current)

            s.close
            log "#{current[:n]} RESOLVED"

            @sockets.delete(current)
          end
        end
        log "event loop end"
      end
    }
  end

  def request url=nil, callback = -> (content, current = nil) {}

    break_line = "\r\n"

    uri = URI(url)
    request_line = "GET / HTTP/1.0#{break_line}"
    headers = [
      "Content-Length:0",
      "Host:#{uri.hostname}"
    ].join(break_line)
    
    # puts [ uri.hostname , uri.port ].join ":"
    
    s = TCPSocket.new uri.hostname, uri.port

    request = [ 
      request_line,
      headers,
      break_line,
      break_line
    ].join("")

    s.write request
    @io_n += 1

    current = { 
      socket: s, 
      callback: callback, 
      result: nil,
      n: @io_n,
      init_time: Time.now.to_f,
      duration: nil,
      write: request
    }


    @sockets << current

    Fiber.new do

      loop do
        if current[:result]
          break
        end
        Fiber.yield nil
      end

      current[:result]
    end
  end
end


url = "http://localhost:3000"

count = 0
client = NoBlockingClient.new

callback =  -> (content, current) { 

  reqline, tail = content.split "\r\n", 2

  protocol, code, status = reqline.split " ", 3

  raw_headers, raw_body = tail.split "\r\n\r\n", 2
  headers = raw_headers.split("\r\n").map do |line| 
    line.split(":", 2)
  end
  .reduce({}) do | memo, current |
    memo[current[0]] = current[1].strip
    memo
  end

  count += 1
  # puts "callbacks called #{count} for item #{current[:n]} in #{current[:duration]} millis"

  raw_body
}


def await fibers

  if fibers.respond_to? :each

    results = Array.new fibers.size, :pending

    while results.count{ |i| i == :pending } > 0 do

      # sleep 0.2
      # run all fibers
      fibers.each_with_index do |fiber, i|

        if fiber.alive?
          result = await fiber
          if result
            results[i] = result
          end
        end
      end
    end
    results
  else
    fibers.resume
  end
end


# With eventLoop
puts "Eventloop " + "-" * 40
initial = Time.now.to_f 

tasks = (1..n).map{ |i| 
  client.request(url, callback) 
}

results = await tasks
puts results

duration = ((Time.now.to_f - initial) * 1000 ).round 3

puts "duration #{duration} millis"


puts "\nSync blocking " + "-" * 40

initial = Time.now.to_f 
uri = URI(url)
results = (1..n).map{ |i| 
  Net::HTTP.get_response(uri).read_body
}

puts results

duration = ((Time.now.to_f - initial) * 1000 ).round 3

puts "duration #{duration} millis"


puts "\nAsync with Threads " + "-" * 40

initial = Time.now.to_f 
uri = URI(url)
tasks = (1..n).map{ |i| 
  Thread.new { 
    Thread.current[:output] = Net::HTTP.get_response(uri) 
  }
}

puts tasks.map(&:join).map{ |t| t[:output].read_body }

duration = ((Time.now.to_f - initial) * 1000 ).round 3

puts "duration #{duration} millis"

