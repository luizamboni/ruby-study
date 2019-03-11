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



def break_line
  "\r\n"
end

def generate_request url
  uri = URI(url)

  request_line = "GET / HTTP/1.0#{break_line}"

  headers = [
    "Content-Length:0",
    "Host:#{uri.hostname}"
  ].join(break_line)
    
  socket = TCPSocket.new uri.hostname, uri.port

  request = [ 
    request_line,
    headers,
    break_line,
    break_line
  ].join("")

  [ socket, request ]
end

def parse_http_content content

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

  raw_body
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

        log " sockets to monitoring: #{sockets.size} "

        if sockets.any? 
          read_sockets, write_sockets, errors = IO.select( sockets, sockets, sockets, 0.1)


          # puts "-" * 40
          # puts "sockets ready to read: #{read_sockets.size}"
          # puts "sockets ready to write: #{write_sockets.size}"

          errors.each do |error|
            puts error.message
          end

          write_sockets.each do |s|
            current = @sockets.find{ |s2| s2[:socket].__id__ == s.__id__ }
            if current[:write]
              s.write current.delete :write
            end
          end

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


    socket, request = generate_request(url)

    # s.write request
    @io_n += 1

    current = { 
      socket: socket, 
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

client = NoBlockingClient.new



callback =  -> (content, current) { 
  parse_http_content content
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
puts "Preemptive Eventloop with one dedicated Thread " + "-" * 40
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
  puts Net::HTTP.get_response(uri).read_body
}

duration = ((Time.now.to_f - initial) * 1000 ).round 3

puts "duration #{duration} millis"


puts "\nAsync with Threads " + "-" * 40

initial = Time.now.to_f 
uri = URI(url)
tasks = (1..n).map{ |i| 
  Thread.new {
    Net::HTTP.get_response(uri).read_body
  }
}

puts tasks.map(&:join).map(&:value)

duration = ((Time.now.to_f - initial) * 1000 ).round 3

puts "duration #{duration} millis"

puts "\nAsync only with fibers with a IO.select by fiber " + "-" * 20
initial = Time.now.to_f


tasks = (1..n).map{ |i| 

  Fiber.new do

    socket, request = generate_request url
    out = nil
    writed = false

    loop do

      reads, writes, errors = IO.select [socket], [socket], [socket], 0.1
      
      read, = reads

      if read
        out = read.read
        break
      end

      write, = writes

      if write && !writed
        write.write request
        writed = true
      end

      Fiber.yield :waiting
    end

    Fiber.yield :ready
    out
  end
}

def await fibers

  results = Array.new fibers.size, :pending

  while results.count{ |i| i == :pending } > 0 do
    
    fibers.each_with_index do |fiber, i|

      if fiber.alive?
        state = fiber.resume

        if state == :ready
          results[i] = parse_http_content fiber.resume
        end
      end
    end
  end

  results
end


puts await tasks
duration = ((Time.now.to_f - initial) * 1000 ).round 3
puts "duration #{duration} millis"


puts "\nAsync only with fibers with one subscribe schedule " + "-" * 20

initial = Time.now.to_f 
tasks = (1..n).map{ |i| 
  socket, request = generate_request url
  { socket: socket, request: request }
}


def subscribe tasks

  results = Array.new tasks.size, :pending

  requests = tasks.reduce({}) do |memo, current|
    memo[ current[:socket].__id__ ] = current[:request]
    memo
  end

  sockets = tasks.map { |entry| entry[:socket] }

  wait_reads = sockets.clone
  wait_writes = sockets.clone

  loop do

    # puts "wait reads #{wait_reads.size}"
    # puts "wait writes #{wait_writes.size}"


    reads, writes, errors = IO.select(wait_reads, wait_writes, wait_writes + wait_reads, 0.1)

  
    (writes || []).each do |s|
      if wait_writes.find_index { |s2| s2.__id__ == s.__id__ }
        s.write requests[s.__id__]
        wait_writes.delete s
      end
    end

    (reads || []).each do |s|
      if wait_reads.find_index { |s2| s2.__id__ == s.__id__ }

        index = tasks.find_index { |entry| entry[:socket].__id__ == s.__id__ }

        results[index] = s.read 
        wait_reads.delete s
      end
    end

    if results.count { |item| item == :pending } == 0
      break
    end
  end
  results.map { |res| parse_http_content(res) }
end


puts subscribe(tasks)

duration = ((Time.now.to_f - initial) * 1000 ).round 3
puts "duration #{duration} millis"