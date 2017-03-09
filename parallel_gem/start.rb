require "parallel"
require "byebug"

options = { in_processes: 3 }

results = Parallel.map(['a','b','c'], options ) { |letter| 
  puts letter 
}

puts options.inspect
# {:in_processes=>3, :mutex=>#<Thread::Mutex:0x000000021781b0>, :return_results=>true}

# it can be avoided cloning a options in begin
# 2.4.0-rc1 :001 > a = {a: "a"} 
#  => {:a=>"a"} 
# 2.4.0-rc1 :002 > b= a.clone
#  => {:a=>"a"} 
# 2.4.0-rc1 :003 > b[:c] = "c"
#  => "c" 
# 2.4.0-rc1 :004 > b
#  => {:a=>"a", :c=>"c"} 
# 2.4.0-rc1 :005 > a
#  => {:a=>"a"} 
# 2.4.0-rc1 :006 > b.object_id
#  => 14202320 
# 2.4.0-rc1 :007 > a.object_id
#  => 14220180 