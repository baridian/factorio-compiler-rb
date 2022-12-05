# frozen_string_literal: true

require './nonterminal'
require './terminal'

# generates parser definitions from
# an ebnf abstract syntax tree
class EbnfCode
  def initialize(ast)
    @ast = ast
  end

  # convert ebnf AST to string
  def to_s
    root = ast
    rules = []
    rule_pointer = ast.children.last
    # convert rules=rules,rule to [rule, rule, ...]
    while(rule_pointer.type == :rules)
      rules << rule_pointer.children.last
      rule_pointer = rule_pointer.children.first
    end
    rules.collect { |rule| rule_to_s(rule) }.reverse.join "\n"
  end

  private

  # rhts is [name,[name,name,...],[name,subterm],subterm]
  # output is an array of compiled rule terms
  # output = [[name,name,...],...]
  def reformat(rhts)
    to_return = []
    primitive_call = []
    rhts_copy = rhts.clone
    pop_last = false
    rhts_copy.each_with_index do |term, index|
      if term.is_a? Array
        if term.length == 1
          term = term.first
        else
          first_element = term.shift
          # append the result of reformat with the rest of the items
          to_return = reformat(rhts_copy)
          # assign as the first element in the array
          term = first_element
        end
      end

      if term.is_a?(Lexeme) && (term.type == :name)
        primitive_call << term.content.gsub(/[^\w]/,"")
      elsif term.is_a?(Lexeme) && term.type == :subterm # is a subterm
        if term.children.first.type == :lgroup
          # get all the primitive rules for the group
          # add the stuff in front to each primitive rule to all the stuff after
          reformat(flatten_rht(rhts_copy[(index + 1)..])).each do |rest_of_terms_prim|
            # get all the primitive rules for everything after the group
            # add all the stuff behind the group to each primitive rule to the front
            reformat(flatten_rht(term.children[1])).each do |group_prim|
              to_return << primitive_call + group_prim + rest_of_terms_prim
            end
            pop_last = true
          end
          break # already did all the terms after
        elsif term.children.first.type == :loptional
          # get all the primitive rules for the group
          # add the stuff in front to each primitive rule to all the stuff after
          reformat(flatten_rht(rhts_copy[(index + 1)..])).each do |rest_of_terms_prim|
            # get all the primitive rules for everything after the group
            # add all the stuff behind the group to each primitive rule to the front
            reformat(flatten_rht(term.children[1])).each do |group_prim|
              # add with and without the optional statement
              to_return << primitive_call + rest_of_terms_prim
              to_return << primitive_call + group_prim + rest_of_terms_prim
            end
          end
          break # already did all the terms after
        else # term.children.first.type == :lrepeat
          repeat_term = "#{reformat(flatten_rht(term.children[1])).flatten.reverse.join('').gsub(/[^\w]/,'')}s"
          primitive_call << repeat_term
          reformat(flatten_rht(term.children[1])).each do |repeat_prim|
            to_return << (['__repeat__',repeat_term] + repeat_prim.reverse)
            to_return << (['__repeat__'] + repeat_prim.reverse)
          end
        end
      else
        raise "unexpected value #{term}"
      end
    end

    to_return << primitive_call
    to_return.pop if pop_last
    to_return
  end

  #convert rhts to array of [name, subterm, [name, subterm] ...]
  # that is: each name encountered is lifted up
  # blocks become arrays
  def flatten_rht(input)
    to_return = []
    if input.is_a? Lexeme
      case input.type
      when :rhts # flatten rhts to [rht, rht, ...] then flatten again
        arr = []
        while(input.type == :rhts)
          arr << input.children.last
          input = input.children.first
        end
        to_return = flatten_rht(arr)
      when :rht # flatten rht to [subter, subterm, ...] then flatten again
        arr = []
        while(input.type == :rht)
          arr << input.children.last
          input = input.children.first
        end
        to_return = flatten_rht(arr)
      when :subterm # flatten subterm to name or array then flatten again
        if input.children.first.type == :name
          to_return = [input.children.first]
        else
          to_return = [input]
        end
      when :name
        to_return = [input]
      end
    elsif input.is_a? Array # flatten each term
      input.each do |term|
        flattened_term = flatten_rht(term)
        if flattened_term.length == 1
          to_return << flattened_term.first
        else
          to_return << flattened_term
        end
      end
    else
      puts input.class
    end
    to_return
  end

  # convert rhts lexeme to an array of strings
  # each string comprising the right hand side
  # of a compiled rule
  def rhts_to_s_array(rhts_pointer)
    # reformat towards output
    s_array = reformat(flatten_rht(rhts_pointer)).collect do |primitive_rht_term_array|
      primitive_rht_term_array.reverse.join ','
    end
    s_array
  end

  # convert one EBNF rule into a set of rules
  def rule_to_s(rule)
    lht = rule.children.first # get the lht
    lht_string = lht.children.first.content # lht=name

    rhts = rhts_to_s_array(rule.children[2])

    skip_next = false
    repeat_lht = nil
    primitive_strings = rhts.collect do  |rht_string|
      if skip_next
        skip_next = false
        "#{repeat_lht}=#{rht_string.split(',').reverse[1..].join(',')}"
      else
        if rht_string.split(",").last == "__repeat__"
          skip_next = true
          new_rht_arr = rht_string.split(",").reverse
          repeat_lht = new_rht_arr[1]
          new_rht_string = new_rht_arr[1..].join(',')
          "#{repeat_lht}=#{new_rht_string}"
        else
          "#{lht_string}=#{rht_string}"
        end
      end
    end

    primitive_strings.join("\n")
  end

  attr_reader :ast
end
