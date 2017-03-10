require 'drb/drb'

# The URI to connect to
SERVER_URI="druby://localhost:8787"

# Start a local DRbServer to handle callbacks.
#
# Not necessary for this small example, but will be required
# as soon as we pass a non-marshallable object as an argument
# to a dRuby call.
#
# Note: this must be called at least once per process to take any effect.
# This is particularly important if your application forks.
DRb.start_service


class Test 

  def initialize value
    @value = value
  end

  def ok 
   { ok: @value}
  end
end

begin

  pid = Process.spawn "ruby server.rb"
  Process.detach(pid)

  puts "pid from server: #{pid}"
rescue Exception => e

end


timeserver = DRbObject.new_with_uri(SERVER_URI)

time  =  timeserver.get_current_time
info  =  timeserver.get_info
test =  timeserver.test

close =  timeserver.close

puts test.class
puts test.ok
# puts test.methods

puts time, info, close