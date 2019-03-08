require "parallel"
require "byebug"

options = { in_processes: 2 }


results = Parallel.map(['a','b','c'], options ) { |letter| 
  puts letter 
}

puts options.inspect