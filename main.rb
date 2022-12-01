# frozen_string_literal: true

require './lex'
require './parse'

lex_defs = File.read 'lexdefs.txt'
lexer = Lex.new lex_defs
lexemes = lexer.run(File.read('test.txt'))

parse_defs = File.read 'parsedefs.txt'
parser = Parse.new parse_defs
puts 'DONE!'
