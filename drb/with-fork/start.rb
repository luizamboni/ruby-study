require "colorize"
require "byebug"

require_relative "server"

include Server

puts "starting...\n\n".green

# shared obj
rd, wr = IO.pipe

callback = lambda do | params |
  rd.close
  limit = 10

  c ||= 0

  while c < limit do
    wr.write "#{params[:name]}#{c} tum tum tum\n".green
    c += 1
  end
  c
end 

workers = (1..40).to_a.map { |i| gen_server(callback, name: "UOW") }
workers = (1..40).to_a.map { |i| gen_server(callback, name: "HEEEY AHHHH" ) }


# Process.kill("TERM", pid)

# wait all child processes
Process.waitall
wr.close

while !rd.eof?
  puts rd.gets
end
# puts rd.read
