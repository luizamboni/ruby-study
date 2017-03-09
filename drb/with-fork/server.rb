module Server 

  def gen_server callback, params=nil

    pid = fork do
      puts "start server #{Process.pid} => #{params[:name]}"
      if params   
        callback.call params
      else
        callback.call
      end
    end
    pid
  end
end