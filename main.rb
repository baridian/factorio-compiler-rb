# frozen_string_literal: true

require './lex'
require './parse'
require './ebnf/ebnfcode'
require './codegen'

# convert bnf style input to internally defined
# basic backhaus-naur form
lex_defs = File.read 'ebnf/lexdefs.txt'
lexer = Lex.new lex_defs
lexemes = lexer.run(File.read('parsedefs.bnf'))

parse_defs = File.read 'ebnf/parsedefs.txt'
parser = Parse.new parse_defs
ast = parser.run(lexemes)
File.write 'parsedefs.txt', EbnfCode.new(ast)

 lex_defs = File.read 'lexdefs.txt'
 lexer = Lex.new lex_defs
 lexemes = lexer.run(File.read('input.txt'))

 parse_defs = File.read 'parsedefs.txt'
 parser = Parse.new parse_defs
 ast = parser.run(lexemes)
 puts CodeGen.new(ast)

#File.delete('parsedefs.txt')