module Server 

  def gen_server callback, params=nil
    name = params && params[:name]
    pid = fork do
      puts "start pid => #{Process.pid}, name => #{name}" 
      if params   
        callback.call params
      else
        callback.call
      end
    end
    pid
  end
end