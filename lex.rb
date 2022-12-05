# frozen_string_literal: true

require './terminal'

# lexical analyzer.
# pulls lex rules from lexdefs.txt
class Lex
  # set up the rules hash. No checking is done to make
  # sure the file is formatted properly.
  def initialize(file)
    @rules_hash = {}
    lines = file.split("\n")
    lines.each do |line|
      # if the line has an assignment but an invalid lValue
      if line.match?(/=/) && !line.match?(/\w+(?==)/)
        # must have valid lValue
        raise "ERROR: cannot parse '#{line}': unrecognized lValue"
      elsif line.match?(/\(\?<=/)
        puts 'each terminal consumes all the string in front of it, and'
        puts 'each terminal tries to match from the start of the line'
        puts 'this functionality plus lookahead allows for effective'
        puts 'look behind.'
        raise "ERROR: cannot parse '#{line}': look behind unsupported"
      end

      pattern = Regexp.new "^#{line.match(%r{(?<==/).*(?=/\w*$)})}"
      @rules_hash[line.match(/\w+(?==)/).to_s] = pattern
    end
  end

  # run the lexer.
  # This takes a string containing the contents of the
  # file to parse and returns an array of LexTokens.
  #
  # Implementation: try all rules against the start of the string.
  # if anything other than exactly one matches, generate and error and abort.
  # if only one matches, create the token and add to to_return
  def run(file)
    file_copy = file.clone.gsub("\n","")
    to_return = []
    # reduce down the string until emtpy
    while file_copy != ''
      # rules that match the input
      matches = []
      # check each rule, add if match
      @rules_hash.each_key do |key|
        pattern = @rules_hash[key]

        matches << { string: file_copy.match(pattern).to_s, key: key } if file_copy.match? pattern
      end

      # if invalid match
      if matches.length != 1
        if matches.length > 1
          puts 'ERROR: Ambiguous input. Multiple rules can be applied:'
          matches.each do |match|
            puts "'#{match[:string]}' => #{match[:key]}"
          end
        else
          puts 'ERROR: No rules for such input:'
        end
        puts "^#{file_copy.match(/.*/).to_s}"
        puts 'please check input and/or lexer rules'
        to_return = nil
        file_copy = ''
      else # valid input
        match_length = matches[0][:string].length
        file_copy = file_copy[match_length..] # chop the match off the front

        # unless its an ignore statement
        unless matches.first[:key] == '__IGNORE__'
          # add the lexeme to the stream
          to_return << Terminal.new(matches.first[:key], matches.first[:string])
        end
      end
    end
    to_return << Terminal.new("$", "")
    to_return 
  end
end
