var http = require('http');

//create a server object:
let low = true;

function latency() { 
  low = !low
  console.log(`latency is low: ${low}`)
  return low ? 100 : 3000
}

http.createServer(function (req, res) {
  
  const latency = latency()
  setTimeout(() => {
    res.write('Hello World!'); //write a response to the client
    res.end(); //end the response
  }, latency)

}).listen(3000, () => {
  console.log("started")
}); //the server object listens on port 8080