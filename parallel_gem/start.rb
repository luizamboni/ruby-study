require "parallel"
require "byebug"
require "mysql2"

options = { in_processes: 2 }
results = Parallel.map(['a','b','c'], options ) { |letter| 
  puts letter 
}

puts options.inspect