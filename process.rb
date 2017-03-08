require "colorize"
# require "byebug"

def gen_server limit=nil
  pid = fork do
    count = 1
    while true
      
      puts "inside fork pid #{Process.pid} #{count+=1}".send(count % 2 === 0 ? :green : :red)
      sleep(0.2)
      exit if count === limit && limit
    end
  end
  pid
end

puts "pid of main process is #{Process.pid}"

puts "before forking"
child_pid = gen_server 5
puts "after forking #{child_pid}"
Process.wait child_pid
puts "after wait child #{child_pid}"


# multiple process
servers_pids = []

4.times do |i|
  servers_pids << gen_server
end

sleep(5)
servers_pids.map do |pid|
  Process.kill("TERM", pid)
end
Process.waitall