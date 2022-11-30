# frozen_string_literal: true

require './lex'

lex_defs = File.read('lexdefs.txt')
lexer = Lex.new(lex_defs)
lexemes = lexer.run(File.read('test.txt'))
puts lexemes
