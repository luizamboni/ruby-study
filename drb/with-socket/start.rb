require "colorize"
require "byebug"
require "socket"

require_relative "server"

include Server

puts "starting...\n\n".green

i = Time.now.to_i
socket_path = "/tmp/ruby#{i}.sock"


listener = UNIXServer.new(socket_path)


callback = lambda do | params |
  s1 = UNIXSocket.new(socket_path)
  c ||= 0
  limit = 10
  while c < limit do
    s1.puts "#{params[:name]} #{c} tum tum tum"
    c += 1
  end
  s1.close
end 

close_callback = lambda do |params|

  s = UNIXSocket.new(socket_path)
  s.puts "CLOSE"
  s.close
end

workers1 = (1..2).to_a.map { |i| gen_server(callback, name: "UOW") }
workers2 = (1..2).to_a.map { |i| gen_server(callback, name: "HEEEY AHHHH" ) }


# wait all child processes
Process.waitall

gen_server(close_callback , name: "close msg")

loop do
  # each connection
  client = listener.accept

  msg = client.read

  puts msg 
  break if (msg == "CLOSE\n")
end
listener.close

# puts sock.read
