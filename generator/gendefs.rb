# frozen_string_literal: true

require './generator/transformation'

# code generator defintions
# returns arrays of transformations
module GenDefs
  def self.bbnf
    to_return = []

    rule = Rule.new :words, [:name]
    reduce_rule = lambda do |children|
      Terminal.new('word_sequence', children[0].content.to_s)
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :words, %i[word_sequence name]
    reduce_rule = lambda do |children|
      Terminal.new('word_sequence', "#{children[0].content},#{children[1].content}")
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :comment, %i[lcomment word_sequence rcomment]
    reduce_rule = lambda do |_|
      Terminal.new('comment_terminal', '')
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :subterm, [:comment_terminal]
    reduce_rule = lambda do |_|
      Terminal.new('subterminal', '')
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :subterm, [:name]
    reduce_rule = lambda do |children|
      Terminal.new('subterminal', children[0].content.to_s)
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :rht, [:subterminal]
    reduce_rule = lambda do |children|
      Terminal.new('rhterminal', children[0].content.to_s)
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :rht, %i[rhterminal or subterminal]
    reduce_rule = lambda do |children|
      Terminal.new('rhterminal', "#{children[0].content}|#{children[2].content}")
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :rhts, [:rhterminal]
    reduce_rule = lambda do |children|
      Terminal.new('rhterminal_sequence', children[0].content.to_s)
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :rhts, %i[rhterminal_sequence comma rhterminal]
    reduce_rule = lambda do |children|
      options = children[2].content.split('|', -1).collect do |rht_sub|
        children[0].content.split('|', -1).collect { |sequence_sub| "#{sequence_sub},#{rht_sub}" }.join('|').gsub(',,', ',').gsub(',|', '|').gsub('|,', '|')
      end
      Terminal.new('rhterminal_sequence', options.join('|'))
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :subterm, %i[lrepeat rhterminal_sequence rrepeat]
    output_rule = lambda do |children|
      string = ''
      repeat_lht = "#{children[1].content.gsub(/,|\|/, '')}s"
      children[1].content.split('|', -1) do |rhterminal|
        string += "#{repeat_lht}=#{repeat_lht},#{rhterminal}\n"
        string += "#{repeat_lht}=#{rhterminal}\n"
      end
      string
    end
    reduce_rule = lambda do |children|
      Terminal.new('subterminal', "#{children[1].content.gsub(/,|\|/, '')}s")
    end
    to_return << Transformation.new(rule, output_rule, reduce_rule)

    rule = Rule.new :subterm, %i[lgroup rhterminal_sequence rgroup]
    reduce_rule = lambda do |children|
      Terminal.new('subterminal', children[1].content.to_s)
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :subterm, %i[loptional rhterminal_sequence roptional]
    reduce_rule = lambda do |children|
      Terminal.new('subterminal', "#{children[1].content}|")
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :lht, [:name]
    reduce_rule = lambda do |children|
      Terminal.new('lhterminal', children[0].content.to_s)
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :rule, %i[lhterminal assign rhterminal_sequence endrule]
    output_rule = lambda do |children|
      strings = children[2].content.split('|').collect do |rhts|
        "#{children[0].content}=#{rhts}".chomp(',')
      end
      "#{strings.join "\n"}\n"
    end
    reduce_rule = lambda do |children|
      Terminal.new('ruleterminal', children[0].content.to_s)
    end
    to_return << Transformation.new(rule, output_rule, reduce_rule)

    rule = Rule.new :rule, %i[lhterminal assign rhterminal_sequence endrule comment_terminal]
    output_rule = lambda do |children|
      strings = children[2].content.split('|').collect do |rhts|
        "#{children[0].content}=#{rhts}".chomp(',')
      end
      "#{strings.join "\n"}\n"
    end
    reduce_rule = lambda do |children|
      Terminal.new('ruleterminal', children[0].content.to_s)
    end
    to_return << Transformation.new(rule, output_rule, reduce_rule)

    rule = Rule.new :rules, [:ruleterminal]
    reduce_rule = lambda do |_|
      Terminal.new('ruleterminal_sequence', '')
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :rules, %i[ruleterminal_sequence ruleterminal]
    reduce_rule = lambda do |_|
      Terminal.new('ruleterminal_sequence', '')
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :__FINAL__, [:ruleterminal_sequence]
    reduce_rule = lambda do |_|
      Terminal.new('final_terminal', '')
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :__FINAL__, %i[ruleterminal_sequence comment_terminal]
    reduce_rule = lambda do |_|
      Terminal.new('final_terminal', '')
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)
  end

  def self.fc_interm
    to_return = []

    rule = Rule.new :directives, %i[directives_terminal directive_terminal]
    reduce_rule = lambda do |_|
      Terminal.new('directives_terminal', '')
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :directives, %i[directive_terminal]
    reduce_rule = lambda do |_|
      Terminal.new('directives_terminal', '')
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :circuits, %i[circuits_terminal circuit_terminal]
    reduce_rule = lambda do |_|
      Terminal.new('circuits_terminal', '')
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :circuits, %i[circuit_terminal]
    reduce_rule = lambda do |_|
      Terminal.new('circuits_terminal', '')
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :__FINAL__, %i[directives_terminal circuits_terminal main_circuit_terminal]
    reduce_rule = lambda do |_|
      Terminal.new('__FINAL___terminal', '')
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :__FINAL__, %i[circuits_terminal main_circuit_terminal]
    reduce_rule = lambda do |_|
      Terminal.new('__FINAL___terminal', '')
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :__FINAL__, %i[directives_terminal main_circuit_terminal]
    reduce_rule = lambda do |_|
      Terminal.new('__FINAL___terminal', '')
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :__FINAL__, %i[main_circuit_terminal]
    reduce_rule = lambda do |_|
      Terminal.new('__FINAL___terminal', '')
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :directive, %i[definekeyword word number_terminal]
    output_rule = ->(children) { "DRCT #{children[1].content}=#{children[2].content}\n"}
    reduce_rule = lambda do |children|
      Terminal.new('directive_terminal', children[1].content)
    end
    to_return << Transformation.new(rule, output_rule, reduce_rule)

    rule = Rule.new :circuit, %i[circuitkeyword word lpar arguments_terminal rpar circuitblock_terminal]
    output_rule = lambda do |children|
      to_output = ''
      to_output += "CRC #{children[1].content}\n"
      to_output += "ARGS #{children[3].content}\n"
      new_lines = children[5].context.split("\n").reject(&:empty?).collect do |line|
        new_line = line
        unless line.include?('INIT') || line.include?('RET')
          if line.include? 'replace:'
            new_line = new_line.gsub 'replace:', "#{children[1].content}:"
          elsif !line.include? ':'
            new_line = "#{children[1].content}:#{new_line}"
          end

          new_line = "#{new_line}<-#{children[1].content}" unless line.include? '<-'
        end
        new_line
      end.join("\n")
      to_output + "#{new_lines}\n"
    end
    reduce_rule = lambda do |_|
      Terminal.new('circuit_terminal', '')
    end
    to_return << Transformation.new(rule, output_rule, reduce_rule)

    rule = Rule.new :circuit, %i[circuitkeyword word lpar rpar circuitblock_terminal]
    output_rule = lambda do |children|
      to_output = ''
      to_output += "CRC #{children[1].content}\n"
      new_lines = children[4].context.split("\n").reject(&:empty?).collect do |line|
        new_line = line
        unless line.include?('INIT') || line.include?('RET')
          if line.include? 'replace:'
            new_line = new_line.gsub 'replace:', "#{children[1].content}:"
          elsif !line.include? ':'
            new_line = "#{children[1].content}:#{new_line}"
          end

          new_line = "#{new_line}<-#{children[1].content}" unless line.include? '<-'
        end
        new_line
      end.join("\n")
      to_output += "#{new_lines}\n"

      to_output
    end
    reduce_rule = lambda do |children|
      Terminal.new('circuit_terminal', children[0].content)
    end
    to_return << Transformation.new(rule, output_rule, reduce_rule)

    rule = Rule.new :commawords, %i[commawords_terminal comma word]
    reduce_rule = lambda do |children|
      Terminal.new('commawords_terminal', "#{children[0].content},#{children[2].content}")
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :commawords, %i[comma word]
    reduce_rule = lambda do |children|
      Terminal.new('commawords_terminal', children[1].content)
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :arguments, %i[word commawords_terminal]
    reduce_rule = lambda do |children|
      Terminal.new('arguments_terminal', "#{children[0].content},#{children[1].content}")
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :arguments, %i[word]
    reduce_rule = lambda do |children|
      Terminal.new('arguments_terminal', children[0].content)
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :initialization, %i[varkeyword arguments_terminal assign circuitcall_terminal semicolon]
    reduce_rule = lambda do |children|
      new_terminal = Terminal.new('initialization_terminal', children[1].content)
      new_context = "INIT #{children[1].content}=#{children[3].content}\n"
      [new_terminal, new_context]
    end
    to_return << Transformation.new(rule, ->(_){ '' }, reduce_rule)

    rule = Rule.new :initialization, %i[varkeyword arguments_terminal semicolon]
    reduce_rule = lambda do |children|
      new_terminal = Terminal.new('initialization_terminal', children[1].content)
      new_context = "INIT #{children[1].content}\n"
      [new_terminal, new_context]
    end
    to_return << Transformation.new(rule, ->(_){ '' }, reduce_rule)

    rule = Rule.new :circuitcall, %i[word lpar arguments_terminal rpar]
    reduce_rule = lambda do |children|
      Terminal.new('circuitcall_terminal', "#{children[0].content}(#{children[2]})")
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :assignment, %i[word assign expression_terminal semicolon]
    reduce_rule = lambda do |children|
      new_terminal = Terminal.new('assignment_terminal', children[0].content)
      new_context = children[2].context + "#{children[0].content}=#{children[2].content}\n"
      [new_terminal, new_context]
    end
    to_return << Transformation.new(rule, ->(_){ '' }, reduce_rule)

    rule = Rule.new :conditional, %i[ifkeyword lpar expression_terminal rpar block_terminal elsekeyword block_terminal]
    reduce_rule = lambda do |children|
      conditional_eval = children[2].content
      pass_circuit = "c#{children[4].hash}:"
      fail_circuit = "c#{children[6].hash}:"
      new_context = children[2].context.split("\n").collect do |line|
        "replace:#{line}"
      end.join("\n") + "\n"

      new_context += "#{pass_circuit}E*=#{conditional_eval}!=0\n"
      new_context += children[4].context.split("\n").collect do |line|
        if line.match? '<-'
          line
        elsif line.match? 'replace:'
          new_line = line.gsub 'replace:', pass_circuit
          "#{new_line}<-#{pass_circuit.chomp ':'}"
        else
          "#{line}<-#{pass_circuit.chomp ':'}"
        end
      end.join("\n") + "\n"
      new_context += "#{fail_circuit}E*=#{conditional_eval}==0\n"
      new_context += children[6].context.split("\n").collect do |line|
        if line.match? '<-'
          line
        else
          "#{line}<-#{fail_circuit.chomp ':'}"
        end
      end.join("\n") + "\n"
      new_terminal = Terminal.new('conditional_terminal', '')
      [new_terminal, new_context]
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :conditional, %i[ifkeyword lpar expression_terminal rpar block_terminal]
    reduce_rule = lambda do |children|
      conditional_eval  = children[2].content
      new_circuit = "c#{children.hash}:"
      new_context = children[2].context.split("\n").collect do |line|
        "replace:#{line}"
      end.join("\n") + "\n"
      new_context += "#{new_circuit}E*=#{conditional_eval}!=0\n"
      new_context += children[4].context.split("\n").collect do |line|
        if line.match? '<-'
          line
        elsif line.match? 'replace:'
          new_line = line.gsub 'replace:', pass_circuit
          "#{new_line}<-#{pass_circuit.chomp ':'}"
        else
          "#{line}<-#{new_circuit.chomp ':'}"
        end
      end.join("\n") + "\n"
      new_terminal = Terminal.new('conditional_terminal', new_circuit)
      [new_terminal, new_context]
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :block, %i[lbrace statements_terminal rbrace]
    reduce_rule = lambda do |children|
      new_terminal = Terminal.new('block_terminal', children[1].content)
      new_context = children[1].context
      [new_terminal, new_context]
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :statement, %i[assignment_terminal]
    reduce_rule = lambda do |children|
      new_terminal = Terminal.new('statement_terminal', children[0].content)
      new_context = children[0].context
      [new_terminal, new_context]
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :statement, %i[conditional_terminal]
    reduce_rule = lambda do |children|
      new_terminal = Terminal.new('statement_terminal', children[0].content)
      new_context = children[0].context
      [new_terminal, new_context]
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :return, %i[returnkeyword arguments_terminal semicolon]
    reduce_rule = lambda do |children|
      Terminal.new('return_terminal', children[1].content)
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :initializations, %i[initializations_terminal initialization_terminal]
    reduce_rule = lambda do |children|
      new_context = "#{children[0].context}#{children[1].context}"
      new_terminal = Terminal.new('initializations_terminal', "#{children[0].content}\n#{children[1].content}")
      [new_terminal, new_context]
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :initializations, %i[initialization_terminal]
    reduce_rule = lambda do |children|
      new_context = children[0].context
      new_terminal = Terminal.new('initializations_terminal', children[0].content)
      [new_terminal, new_context]
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :statements, %i[statements_terminal statement_terminal]
    reduce_rule = lambda do |children|
      new_terminal = Terminal.new('statements_terminal', '')
      new_context = children[0].context + children[1].context
      [new_terminal, new_context]
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :statements, %i[statement_terminal]
    reduce_rule = lambda do |children|
      new_terminal = Terminal.new('statements_terminal', '')
      new_context = children[0].context
      [new_terminal, new_context]
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :circuitblock, %i[lbrace initializations_terminal statements_terminal return_terminal rbrace]
    reduce_rule = lambda do |children|
      new_context = "#{children[1].context}#{children[2].context}\nRET #{children[3].content}"
      new_terminal = Terminal.new('circuitblock_terminal', 'block')
      [new_terminal, new_context]
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :logicalorlogicalAndExpressions, %i[logicalorlogicalAndExpressions_terminal logicalor logicalAndExpression_terminal]
    reduce_rule = lambda do |children|
      new_terminal = Terminal.new('logicalorlogicalAndExpressions_terminal', "t#{children.hash}")
      new_context = children[0].context + "t#{children.hash}=#{children[0].content}||#{children[1].content}\n"
      [new_terminal, new_context]
    end
    to_return << Transformation.new(rule, ->(_){ '' }, reduce_rule)

    rule = Rule.new :logicalorlogicalAndExpressions, %i[logicalor logicalAndExpression_terminal]
    reduce_rule = lambda do |children|
      new_context = children[1].context
      new_terminal = Terminal.new('logicalorlogicalAndExpressions_terminal', "#{children[1].content}")
      [new_terminal, new_context]
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :expression, %i[logicalAndExpression_terminal logicalorlogicalAndExpressions_terminal]
    reduce_rule = lambda do |children|
      new_terminal = Terminal.new('expression_terminal', "t#{children.hash}")
      new_context = children[0].context + children[1].context + "t#{children.hash}=#{children[0].content}||#{children[1].content}\n"
      [new_terminal, new_context]
    end
    to_return << Transformation.new(rule, ->(_){ '' }, reduce_rule)

    rule = Rule.new :expression, %i[logicalAndExpression_terminal]
    reduce_rule = lambda do |children|
      new_terminal = Terminal.new('expression_terminal', children[0].content)
      new_context = children[0].context
      [new_terminal, new_context]
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :logicalandbitOrExpressions, %i[logicalandbitOrExpressions_terminal logicaland bitOrExpression_terminal]
    reduce_rule = lambda do |children|
      new_terminal = Terminal.new('logicalandbitOrExpressions_terminal', "t#{children.hash}")
      new_context = children[0].context + "t#{children.hash}=#{children[0].content}&&#{children[2].content}\n"
      [new_terminal, new_context]
    end
    to_return << Transformation.new(rule, ->(_){ '' }, reduce_rule)

    rule = Rule.new :logicalandbitOrExpressions, %i[logicaland bitOrExpression_terminal]
    reduce_rule = lambda do |children|
      new_terminal = Terminal.new('logicalandbitOrExpressions_terminal', "#{children[1].content}")
      new_context = children[1].context
      [new_terminal, new_context]
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :logicalAndExpression, %i[bitOrExpression_terminal logicalandbitOrExpressions_terminal]
    reduce_rule = lambda do |children|
      new_terminal = Terminal.new('logicalAndExpression_terminal', "t#{children.hash}")
      new_context = children[0].context + children[1].context + "t#{children.hash}=#{children[0].content}&&#{children[1].content}\n"
      [new_terminal, new_context]
    end
    to_return << Transformation.new(rule, ->(_){ '' }, reduce_rule)

    rule = Rule.new :logicalAndExpression, %i[bitOrExpression_terminal]
    reduce_rule = lambda do |children|
      new_terminal = Terminal.new('logicalAndExpression_terminal', children[0].content)
      new_context = children[0].context
      [new_terminal, new_context]
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :bitorbitXorExpressions, %i[bitorbitXorExpressions_terminal bitor bitXorExpression_terminal]
    reduce_rule = lambda do |children|
      new_terminal = Terminal.new('bitorbitXorExpressions_terminal', "t#{children.hash}")
      new_context = children[0].context + "t#{children.hash}=#{children[0].content}|#{children[2].content}\n"
      [new_terminal, new_context]
    end
    to_return << Transformation.new(rule, ->(_){ '' }, reduce_rule)

    rule = Rule.new :bitorbitXorExpressions, %i[bitor bitXorExpression_terminal]
    reduce_rule = lambda do |children|
      new_context = children[1].context
      Terminal.new('bitorbitXorExpressions_terminal', "#{children[1].content}")
      [new_terminal, new_context]
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :bitOrExpression, %i[bitXorExpression_terminal bitorbitXorExpressions_terminal]
    reduce_rule = lambda do |children|
      new_terminal = Terminal.new('bitOrExpression_terminal', "t#{children.hash}")
      new_context = children[0].context + children[1].context + "t#{children.hash}=#{children[0].content}|#{children[1].content}\n"
      [new_terminal, new_context]
    end
    to_return << Transformation.new(rule, ->(_){ '' }, reduce_rule)

    rule = Rule.new :bitOrExpression, %i[bitXorExpression_terminal]
    reduce_rule = lambda do |children|
      new_terminal = Terminal.new('bitOrExpression_terminal', children[0].content)
      new_context = children[0].context
      [new_terminal, new_context]
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :bitxorbitAndExpressions, %i[bitxorbitAndExpressions_terminal bitxor bitAndExpression_terminal]
    reduce_rule = lambda do |children|
      new_terminal = Terminal.new('bitxorbitAndExpressions_terminal', "t#{children.hash}")
      new_context = children[0].context + "t#{children.hash}=#{children[0].content}^#{children[2].content}\n"
      [new_terminal, new_context]
    end
    to_return << Transformation.new(rule, ->(_){ '' }, reduce_rule)

    rule = Rule.new :bitxorbitAndExpressions, %i[bitxor bitAndExpression_terminal]
    reduce_rule = lambda do |children|
      new_context = children[1].context
      new_terminal = Terminal.new('bitxorbitAndExpressions_terminal', "#{children[1].content}")
      [new_terminal, new_context]
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :bitXorExpression, %i[bitAndExpression_terminal bitxorbitAndExpressions_terminal]
    reduce_rule = lambda do |children|
      new_terminal = Terminal.new('bitXorExpression_terminal', "t#{children.hash}")
      new_context = children[0].context + children[1].context + "t#{children.hash}=#{children[0].content}^#{children[1].content}\n"
      [new_terminal, new_context]
    end
    to_return << Transformation.new(rule, ->(_){ '' }, reduce_rule)

    rule = Rule.new :bitXorExpression, %i[bitAndExpression_terminal]
    reduce_rule = lambda do |children|
      new_terminal = Terminal.new('bitXorExpression_terminal', children[0].content)
      new_context = children[0].context
      [new_terminal, new_context]
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :bitandequalityExpressions, %i[bitandequalityExpressions_terminal bitand equalityExpression_terminal]
    reduce_rule = lambda do |children|
      new_terminal = Terminal.new('bitandequalityExpressions_terminal', "t#{children.hash}")
      new_context = children[0].context + "t#{children.hash}=#{children[0].content}&#{children[2].content}\n"
      [new_terminal, new_context]
    end
    to_return << Transformation.new(rule, ->(_){ '' }, reduce_rule)

    rule = Rule.new :bitandequalityExpressions, %i[bitand equalityExpression_terminal]
    reduce_rule = lambda do |children|
      new_context = children[1].context
      new_terminal = Terminal.new('bitandequalityExpressions_terminal', "#{children[1].content}")
      [new_terminal, new_context]
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :bitAndExpression, %i[equalityExpression_terminal bitandequalityExpressions_terminal]
    reduce_rule = lambda do |children|
      new_terminal = Terminal.new('bitAndExpression_terminal', "t#{children.hash}")
      new_context = children[0].context + children[1].context + "t#{children.hash}=#{children[0].content}&#{children[1].content}\n"
      [new_terminal, new_context]
    end
    to_return << Transformation.new(rule, ->(_){ '' }, reduce_rule)

    rule = Rule.new :bitAndExpression, %i[equalityExpression_terminal]
    reduce_rule = lambda do |children|
      new_terminal = Terminal.new('bitAndExpression_terminal', children[0].content)
      new_context = children[0].context
      [new_terminal, new_context]
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :equalscomparisonExpressiondoesnotequalcomparisonExpressions, %i[equalscomparisonExpressiondoesnotequalcomparisonExpressions_terminal equals comparisonExpression_terminal]
    reduce_rule = lambda do |children|
      new_terminal = Terminal.new('equalscomparisonExpressiondoesnotequalcomparisonExpressions_terminal', "#{children[0].slice(0...2)}t#{children.hash}")
      new_context = children[0].context + "t#{children.hash}=#{children[0].slice(2..).content}==#{children[2].content}\n"
      [new_terminal, new_context]
    end
    to_return << Transformation.new(rule, ->(_){ '' }, reduce_rule)

    rule = Rule.new :equalscomparisonExpressiondoesnotequalcomparisonExpressions, %i[equals comparisonExpression_terminal]
    reduce_rule = lambda do |children|
      new_context = children[1].context
      new_terminal = Terminal.new('equalscomparisonExpressiondoesnotequalcomparisonExpressions_terminal', "==#{children[1].content}")
      [new_terminal, new_context]
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :equalscomparisonExpressiondoesnotequalcomparisonExpressions, %i[equalscomparisonExpressiondoesnotequalcomparisonExpressions_terminal doesnotequal comparisonExpression_terminal]
    reduce_rule = lambda do |children|
      new_terminal = Terminal.new('equalscomparisonExpressiondoesnotequalcomparisonExpressions_terminal', "#{children[0].slice(0...2)}t#{children.hash}")
      new_context = children[0].context + "t#{children.hash}=#{children[0].content}!=#{children[2].content}\n"
      [new_terminal, new_context]
    end
    to_return << Transformation.new(rule, ->(_){ '' }, reduce_rule)

    rule = Rule.new :equalscomparisonExpressiondoesnotequalcomparisonExpressions, %i[doesnotequal comparisonExpression_terminal]
    reduce_rule = lambda do |children|
      new_context = children[1].context
      new_terminal = Terminal.new('equalscomparisonExpressiondoesnotequalcomparisonExpressions_terminal', "!=#{children[1].content}")
      [new_terminal, new_context]
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :equalityExpression, %i[comparisonExpression_terminal equalscomparisonExpressiondoesnotequalcomparisonExpressions_terminal]
    reduce_rule = lambda do |children|
      new_terminal = Terminal.new('equalityExpression_terminal', "t#{children.hash}")
      new_context = children[0].context + children[1].context + "t#{children.hash}=#{children[0].content}#{children[1].content}\n"
      [new_terminal, new_context]
    end
    to_return << Transformation.new(rule, ->(_){ '' }, reduce_rule)

    rule = Rule.new :equalityExpression, %i[comparisonExpression_terminal]
    reduce_rule = lambda do |children|
      new_terminal = Terminal.new('equalityExpression_terminal', children[0].content)
      new_context = children[0].context
      [new_terminal, new_context]
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :lessthanshiftExpressiongreaterthanshiftExpressions, %i[lessthanshiftExpressiongreaterthanshiftExpressions_terminal lessthan shiftExpression_terminal]
    reduce_rule = lambda do |children|
      new_terminal = Terminal.new('lessthanshiftExpressiongreaterthanshiftExpressions_terminal', "#{children[0].slice(0)}t#{children.hash}")
      new_context = children[0].context + "t#{children.hash}=#{children[0].content.slice(1..)}<#{children[2].content}\n"
      [new_terminal, new_context]
    end
    to_return << Transformation.new(rule, ->(_){ '' }, reduce_rule)

    rule = Rule.new :lessthanshiftExpressiongreaterthanshiftExpressions, %i[lessthan shiftExpression_terminal]
    reduce_rule = lambda do |children|
      new_context = children[1].context
      new_terminal = Terminal.new('lessthanshiftExpressiongreaterthanshiftExpressions_terminal', "<#{children[1].content}")
      [new_terminal, new_context]
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :lessthanshiftExpressiongreaterthanshiftExpressions, %i[lessthanshiftExpressiongreaterthanshiftExpressions_terminal greaterthan shiftExpression_terminal]
    reduce_rule = lambda do |children|
      new_terminal = Terminal.new('lessthanshiftExpressiongreaterthanshiftExpressions_terminal', "#{children[0].slice(0)}t#{children.hash}")
      new_context = children[0].context + "t#{children.hash}=#{children[0].content.slice(1..)}>#{children[2].content}\n"
      [new_terminal, new_context]
    end
    to_return << Transformation.new(rule, ->(_){ '' }, reduce_rule)

    rule = Rule.new :lessthanshiftExpressiongreaterthanshiftExpressions, %i[greaterthan shiftExpression_terminal]
    reduce_rule = lambda do |children|
      new_context = children[1].context
      new_terminal = Terminal.new('lessthanshiftExpressiongreaterthanshiftExpressions_terminal', ">#{children[1].content}")
      [new_terminal, new_context]
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :comparisonExpression, %i[shiftExpression_terminal lessthanshiftExpressiongreaterthanshiftExpressions_terminal]
    reduce_rule = lambda do |children|
      new_terminal = Terminal.new('comparisonExpression_terminal', "t#{children.hash}")
      new_context = children[1].context + "t#{children.hash}=#{children[0].content}#{children[1].content}\n"
      [new_terminal, new_context]
    end
    to_return << Transformation.new(rule, ->(_){ '' }, reduce_rule)

    rule = Rule.new :comparisonExpression, %i[shiftExpression_terminal]
    reduce_rule = lambda do |children|
      new_terminal = Terminal.new('comparisonExpression_terminal', children[0].content)
      new_context = children[0].context
      [new_terminal, new_context]
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :lshiftaddExpressionrshiftaddExpressions, %i[lshiftaddExpressionrshiftaddExpressions_terminal lshift addExpression_terminal]
    reduce_rule = lambda do |children|
      new_terminal = Terminal.new('lshiftaddExpressionrshiftaddExpressions_terminal', "#{children[0].content.slice(0...2)}t#{children.hash}")
      new_context = children[0].context + "t#{children.hash}=#{children[0].content.slice(2..)}<<#{children[2].content}\n"
      [new_terminal, new_context]
    end
    to_return << Transformation.new(rule, ->(_){ '' }, reduce_rule)

    rule = Rule.new :lshiftaddExpressionrshiftaddExpressions, %i[lshift addExpression_terminal]
    reduce_rule = lambda do |children|
      new_context = children[1].context
      new_terminal = Terminal.new('lshiftaddExpressionrshiftaddExpressions_terminal', "<<#{children[1].content}")
      [new_terminal, new_context]
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :lshiftaddExpressionrshiftaddExpressions, %i[lshiftaddExpressionrshiftaddExpressions_terminal rshift addExpression_terminal]
    reduce_rule = lambda do |children|
      new_terminal = Terminal.new('lshiftaddExpressionrshiftaddExpressions_terminal', "#{children[0].content.slice(0...2)}t#{children.hash}")
      new_context = children[0].context + "t#{children.hash}=#{children[0].content.slice(2..)}>>#{children[2].content}\n"
      [new_terminal, new_context]
    end
    to_return << Transformation.new(rule, ->(_){ '' }, reduce_rule)

    rule = Rule.new :lshiftaddExpressionrshiftaddExpressions, %i[rshift addExpression_terminal]
    reduce_rule = lambda do |children|
      new_context = children[1].context
      new_terminal = Terminal.new('lshiftaddExpressionrshiftaddExpressions_terminal', ">>#{children[1].content}")
      [new_terminal, new_context]
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :shiftExpression, %i[addExpression_terminal lshiftaddExpressionrshiftaddExpressions_terminal]
    reduce_rule = lambda do |children|
      new_terminal = Terminal.new('shiftExpression_terminal', "t#{children.hash}")
      new_context = children[0].context + children[1].context + "t#{children.hash}=#{children[0]}#{children[1]}\n"
      [new_terminal, new_context]
    end
    to_return << Transformation.new(rule, ->(_){ '' }, reduce_rule)

    rule = Rule.new :shiftExpression, %i[addExpression_terminal]
    reduce_rule = lambda do |children|
      new_terminal = Terminal.new('shiftExpression_terminal', children[0].content)
      new_context = children[0].context
      [new_terminal, new_context]
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :plustimesExpressionminustimesExpressions, %i[plustimesExpressionminustimesExpressions_terminal plus timesExpression_terminal]
    reduce_rule = lambda do |children|
      new_terminal = Terminal.new('plustimesExpressionminustimesExpressions_terminal', "#{children[0].content.slice(0)}t#{children.hash}")
      new_context = children[0].context + "t#{children.hash}=#{children[0].content.slice(1..)}+#{children[2].content}\n"
      [new_terminal, new_context]
    end
    to_return << Transformation.new(rule, ->(_){ '' }, reduce_rule)

    rule = Rule.new :plustimesExpressionminustimesExpressions, %i[plus timesExpression_terminal]
    reduce_rule = lambda do |children|
      new_context = children[1].context
      new_terminal = Terminal.new('plustimesExpressionminustimesExpressions_terminal', "+#{children[1].content}")
      [new_terminal, new_context]
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :plustimesExpressionminustimesExpressions, %i[plustimesExpressionminustimesExpressions_terminal minus timesExpression_terminal]
    reduce_rule = lambda do |children|
      new_terminal = Terminal.new('plustimesExpressionminustimesExpressions_terminal', "#{children[0].content.slice(0)}t#{children.hash}")
      new_context = children[0].context + "t#{children.hash}=#{children[0].content.slice(1..)}-#{children[2].content}\n"
      [new_terminal, new_context]
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :plustimesExpressionminustimesExpressions, %i[minus timesExpression_terminal]
    reduce_rule = lambda do |children|
      new_context = children[1].context
      new_terminal = Terminal.new('plustimesExpressionminustimesExpressions_terminal', "-#{children[1].content}")
      [new_terminal, new_context]
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :addExpression, %i[timesExpression_terminal plustimesExpressionminustimesExpressions_terminal]
    reduce_rule = lambda do |children|
      new_terminal = Terminal.new('addExpression_terminal', "t#{children.hash}")
      new_context = children[0].context + children[1].context + "t#{children.hash}=#{children[0].content}#{children[1].content}\n"
      [new_terminal, new_context]
    end
    to_return << Transformation.new(rule, ->(_){ '' }, reduce_rule)

    rule = Rule.new :addExpression, %i[timesExpression_terminal]
    reduce_rule = lambda do |children|
      new_terminal = Terminal.new('addExpression_terminal', children[0].content)
      new_context = children[0].context
      [new_terminal, new_context]
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :timestermovertermmodterms, %i[timestermovertermmodterms_terminal times term_terminal]
    reduce_rule = lambda do |children|
      new_terminal = Terminal.new('timestermovertermmodterms_terminal', "#{children[0].content.slice(0)}t#{children.hash}")
      new_context = children[0].context + "t#{children.hash}=#{children[0].content.slice(1..)}*#{children[2].content}\n"
      [new_terminal, new_context]
    end
    to_return << Transformation.new(rule, ->(_){ '' }, reduce_rule)

    rule = Rule.new :timestermovertermmodterms, %i[times term_terminal]
    reduce_rule = lambda do |children|
      new_context = children[1].context
      new_terminal = Terminal.new('timestermovertermmodterms_terminal', "*#{children[1].content}")
      [new_terminal, new_context]
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :timestermovertermmodterms, %i[timestermovertermmodterms_terminal over term_terminal]
    reduce_rule = lambda do |children|
      new_terminal = Terminal.new('timestermovertermmodterms_terminal', "#{children[0].content.slice(0)}t#{children.hash}")
      new_context = children[0].context + "t#{children.hash}=#{children[0].content.slice(1..)}/#{children[2].content}\n"
      [new_terminal, new_context]
    end
    to_return << Transformation.new(rule, ->(_){ '' }, reduce_rule)

    rule = Rule.new :timestermovertermmodterms, %i[over term_terminal]
    reduce_rule = lambda do |children|
      new_context = children[1].context
      new_terminal = Terminal.new('timestermovertermmodterms_terminal', "/#{children[1].content}")
      [new_terminal, new_context]
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :timestermovertermmodterms, %i[timestermovertermmodterms_terminal mod term_terminal]
    reduce_rule = lambda do |children|
      new_terminal = Terminal.new('timestermovertermmodterms_terminal', "#{children[0].content.slice(0)}t#{children.hash}")
      new_context = children[0].context + "t#{children.hash}=#{children[0].content.slice(1..)}%#{children[2].content}\n"
      [new_terminal, new_context]
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :timestermovertermmodterms, %i[mod term_terminal]
    reduce_rule = lambda do |children|
      new_context = children[1].context
      new_terminal = Terminal.new('timestermovertermmodterms_terminal', "%#{children[1].content}")
      [new_terminal, new_context]
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :timesExpression, %i[term_terminal timestermovertermmodterms_terminal]
    reduce_rule = lambda do |children|
      new_terminal = Terminal.new('timesExpression_terminal', "t#{children.hash}")
      new_context = children[0].context + children[1].context + "t#{children.hash}=#{children[0].content}#{children[1].content}\n"
      [new_terminal, new_context]
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :timesExpression, %i[term_terminal]
    reduce_rule = lambda do |children|
      new_terminal = Terminal.new('timesExpression_terminal', children[0].content)
      new_context = children[0].context
      [new_terminal, new_context]
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :term, %i[word]
    reduce_rule = lambda do |children|
      Terminal.new('term_terminal', children[0].content)
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :term, %i[number_terminal]
    reduce_rule = lambda do |children|
      Terminal.new('term_terminal', children[0].content)
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :term, %i[lpar expression_terminal rpar]
    reduce_rule = lambda do |children|
      Terminal.new('term_terminal', children[1].content)
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :number, %i[hexnumber]
    reduce_rule = lambda do |children|
      Terminal.new('number_terminal', children[0].content.to_i(16).to_s)
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :number, %i[decimalnumber]
    reduce_rule = lambda do |children|
      Terminal.new('number_terminal', children[0].content)
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    rule = Rule.new :main_circuit, %i[circuit_terminal]
    reduce_rule = lambda do |_|
      Terminal.new('main_circuit_terminal', '')
    end
    to_return << Transformation.new(rule, ->(_) { '' }, reduce_rule)

    to_return
  end
end
