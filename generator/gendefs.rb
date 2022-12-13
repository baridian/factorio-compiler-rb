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
  end
end
