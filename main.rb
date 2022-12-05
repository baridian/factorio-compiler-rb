# frozen_string_literal: true

require './lex'
require './parse'
require './ebnf/ebnfcode'

# convert bnf style input to internally defined
# basic backhaus-naur form
lex_defs = File.read 'ebnf/lexdefs.txt'
lexer = Lex.new lex_defs
lexemes = lexer.run(File.read('parsedef.bnf'))

parse_defs = File.read 'ebnf/parsedefs.txt'
parser = Parse.new parse_defs
ast = parser.run(lexemes)
puts EbnfCode.new(ast)
