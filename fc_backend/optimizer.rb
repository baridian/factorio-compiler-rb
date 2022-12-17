# frozen_string_literal: true

# call peephole to run the optimize function over a sliding window
# execution time is <10x slower and almost every line is passed over 10x
module Optimizer
  # runs an unesseccary assignment optimization. Further optimizations can be added later
  def self.optimize(segment)
    raise "ERROR: expected String type, got #{segment.class}" unless segment.is_a? String

    # c0:t1=mem+1<-c0
    # counter:mem=t1<-c0
    #                              1        2           3                 4         5        6
    #                             c0    :  t1  =      mem+1          <-  c0      counter :  mem     =t1<-c0
    uneccessary_assignment = /(\w+):(t\d+)=(\w+.*?\w+)<-(c\d+)\n(\w+):(\w+)=\2<-\1/

    segment.gsub(uneccessary_assignment) do |matched_string|
      match = matched_string.match uneccessary_assignment
      #  counter  :   mem     =    mem+1  <-    c0
      "#{match[5]}:#{match[6]}=#{match[3]}<-#{match[4]}"
    end
  end 
end
