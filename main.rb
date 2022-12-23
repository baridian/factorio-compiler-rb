# frozen_string_literal: true

require './lexer/lex'
require './parser/parse'
require './generator/gendefs'
require './generator/codegen'
require './fc_backend/semantic_analyzer'

BUILD_BBNF = false

if BUILD_BBNF
  # convert bnf style input to internally defined
  # basic backhaus-naur form
  lex_defs = File.read 'ebnf/lexdefs.txt'
  lexer = Lex.new lex_defs
  lexemes = lexer.run(File.read('fc_interm/parsedefs.bnf'))

  parse_defs = File.read 'ebnf/parsedefs.txt'
  parser = Parse.new parse_defs
  ast = parser.run lexemes

  generator = CodeGen.new GenDefs.bbnf
  File.write 'fc_interm/parsedefs.txt', generator.run(ast)

  parse_defs = File.read 'fc_interm/parsedefs.txt'
  parser = Parse.new parse_defs

  File.open('fc_interm/parser.rob', 'wb') { |io| Marshal.dump(parser, io) }
end

lex_defs = File.read 'fc_interm/lexdefs.txt'
lexer = Lex.new lex_defs
lexemes = lexer.run(File.read('input.txt'))

parser = File.open('fc_interm/parser.rob', 'rb') { |io| Marshal.load(io) }
ast = parser.run lexemes

generator = CodeGen.new GenDefs.fc_interm
fc_interm = generator.run(ast)
optimizer_operations = %i[optimize check_var_names remove_uncalled_circuits expand_circuit_calls_for_file]

optimizer_operations.each do |operation|
  fc_interm = SemanticAnalyzer.send(operation, fc_interm)
end

File.write 'fc_backend/interm.txt', fc_interm
