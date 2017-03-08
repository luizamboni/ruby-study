require 'drb/drb'

# The URI for the server to connect to
URI="druby://localhost:8787"

class Test 

  def initialize value
    @value = value
  end

  def ok 
    @value
  end
end

class TimeServer

  def get_current_time
    return Time.now
  end

  def test
    return Test.new("testado")
  end

  def get_info 
    puts "return info"
    return {
      a: "a",
      server: TimeServer.to_s
    }
  end

  def close
    puts "CLOSE"
    DRb.stop_service
  end

end

# The object that handles requests on the server
FRONT_OBJECT=TimeServer.new

$SAFE = 1   # disable eval() and friends

DRb.start_service(URI, FRONT_OBJECT)
# Wait for the drb server thread to finish before exiting.
DRb.thread.join