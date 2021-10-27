# A very basic HTTP server
require "http/server"

server = HTTP::Server.new do |context|
  context.response.content_type = "text/plain"
  context.response.print "Hello world!"
end

Signal::INT.trap do
  puts "Shutdown requested."
  server.close
end

ipaddr = server.bind_tcp("0.0.0.0", 8080)

puts "Listening on http://#{ipaddr.address}:#{ipaddr.port}/"
server.listen
