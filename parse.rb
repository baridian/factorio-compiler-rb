# frozen_string_literal: true

require './terminal'
require './nonterminal'

# parse is an implementation
# of a parser generator and an
# LR parser.
# it reads in rules from a file,
# generates the parser state file,
# and then can parse files given to it.
#
# parsing converts a sequence of terminal lexemes
# created by lex.rb into a tree by placing them
# inside nested non-terminal lexemes as defined by
# the rules file.
# It can also automatically detect grammar errors
# and rule errors.
class Parse
  # generate the parse table from the rule file
  def initialize(rule_file)
    rules = extract_rules(rule_file)
    @nt_syms = rules.map(&:lht).uniq
    @t_syms = rules.map(&:rhts).flatten.uniq - @nt_syms
    @t_syms << :"$" # add special end of sequence lexeme
    @table = generate_table(rules)
    puts table
  end

  # generate the AST from the input sequence
  def run(terminals)

  end

  private

  attr_reader :nt_syms, :t_syms, :table

  # a rule contains a left hand term, a lexeme to reduce to,
  # and right hand terms, that list the lexemes
  # and the order needed to generate the lht
  class Rule
    attr_reader :lht, :rhts

    # create a new rule.
    # lht is a non-determinant lexeme symbol
    # rhts is an array of lexeme symbols
    def initialize(lht, rhts)
      raise "Invalid init for Rule: #{lht}, #{rhts}" unless lht.is_a?(Symbol) && rhts.is_a?(Array)

      @lht = lht
      @rhts = rhts
    end

    def to_s
      "< lht #{lht}>, <rhts #{rhts}>"
    end

    def ==(other)
      other.is_a?(Rule) && other.lht == lht && other.rhts == rhts
    end

    # wrapper of ==
    def eql?(other)
      self == other
    end

    def hash
      return to_s.hash
    end
  end

  # input: string that contains the content of the rule file
  # output: [rule, rule, ...]
  def extract_rules(rule_file)
    to_return = []
    lines = rule_file.split "\n"
    lines.each do |line|
      lht = line.match(/^\w+(?==)/).to_s
      rht = line.match(/(?<==).*(?=\s*$)/).to_s
      rhts = rht.split(',')
      to_return << Rule.new(lht.to_sym, rhts.map(&:to_sym))
    end
    to_return
  end

  # contains the type and the action
  # only can be initialized with no content and then set afterwards
  # checks input validity for action type
  class Action
    attr_reader :type
    attr_accessor :value

    # all the acceptable action types
    def valid_types
      %i[GOTO DONE SHIFT REDUCE]
    end

    # create an empty Action
    def initialize
      @type = nil
      @value = nil
    end

    # check the type and set it
    def type=(type)
      raise  "unknown action type #{type}. Must be #{valid_types}" unless valid_types.include?(type)

      @type = type
    end

    def to_s
      "< type #{type}>, < value #{value}>"
    end

    def ==(other)
      other.is_a?(Action) && other.type == type && other.value == value
    end

    # wrapper of ==
    def eql?(other)
      self == other
    end

    def hash
      return to_s.hash
    end
  end

  # parse table. This contains a set of rows.
  # each row has columns defined by non-terminals and terminals,
  # and an action is held in each cell.
  # its used by the parser to convert a terminal lexeme sequence into
  # an AST.
  class Table
    def initialize(terminal_symbols, nonterminal_symbols)
      @terminals = terminal_symbols
      @nonterminals = nonterminal_symbols
      @table = []
    end

    # adds an empty row to the end of the table
    def add_row
      table << new_empty_row
      nil
    end

    # get the action
    def action(row_num, lexeme)
      unless terminals.include?(lexeme) || nonterminals.include?(lexeme)
        raise "unrecognized lexeme #{lexeme}"
      end

      row = row(row_num)
      if terminals.include? lexeme
        row[:terminals][lexeme]
      else # in nonterminals
        row[:nonterminals][lexeme]
      end
    end

    def num_rows
      table.length
    end

    def to_s
      "< terminals #{terminals}>,  < nonterminals #{nonterminals}>, < table #{table}>"
    end

    private

    # returns a row from the table
    def row(row_num)
      unless row_num >= 0 && row_num < table.length
        raise "tried to get row #{row_num} but table only has #{table.length} rows"
      end

      table[row_num]
    end

    # generates a new empty row and appends it
    def new_empty_row
      to_return = { terminals: {}, nonterminals: {} }
      terminals.each do |terminal|
        to_return[:terminals][terminal] = Action.new
      end
      nonterminals.each do |nonterminal|
        to_return[:nonterminals][nonterminal] = Action.new
      end

      to_return
    end

    attr_reader :terminals, :nonterminals, :table
  end

  # takes the rules array and a symbol
  # recursively finds all terminals that can start for the given
  # symbol. nt_sym = nonterminal symbol
  def find_start_for_symbol(nt_sym, rules)
    to_return = []
    rules.each do |rule|
      if rule.lht == nt_sym
        if t_syms.include? rule.rhts.first # add to the starts for this sym
          to_return << rule.rhts.first
        elsif nt_sym != rule.rhts.first # is an nt and not recursive. Add its start symbols
          to_return += find_start_for_symbol(rule.rhts.first, rules)
        end
      end
    end
    to_return.uniq # dont need duplicate terminals
  end

  # input: [rule, rule, ...]
  # output {symbol => [symbol, symbol, ...], ...}
  # takes in the rules and generates a hash with the set of
  # terminals that always appear at the start of the non-terminals
  def start(rules)
    to_return = {}
    # set up to_return
    rules.each do |rule|
      to_return[rule.lht] = []
    end

    # call recursive function on each key
    to_return.each_key do |nonterminal|
      to_return[nonterminal] = find_start_for_symbol(nonterminal, rules)
    end

    to_return
  end

  # takes a symbol to find all follows for, a hash of symbols=> valid Lmost terminals,
  # and the rules array.
  # generates an array of all the valid following terminals.
  def find_follows_for_symbol(nt_sym, starts, rules)
    to_return = []
    rules.each do |rule|
      rule.rhts.each_with_index do |rule_sym, index|
        if rule_sym == nt_sym
          if index < rule.rhts.length - 1 # if not the last symbol
            if t_syms.include?(rule.rhts[index + 1]) # if next symbol is a terminal
              to_return << rule.rhts[index + 1] # add it
            else # is a nonTerminal
              to_return += starts[rule.rhts[index + 1]] # add the lmost valid terminals
            end
          else # is the last symbol in the rule
            unless rule.lht != rule.rhts[index]
              raise "ERROR: rightmost recursion cannot be parsed. Check '#{rule.lht}'"
            end

            # so add the follows of the nt that it tails
            to_return += find_follows_for_symbol(rule.lht, starts, rules)
          end
        end
      end
    end
    # __FINAL__ can be followed by $
    to_return << :"$" if nt_sym == :__FINAL__

    to_return.uniq # dont need duplicates
  end

  # input: [rule, rule, ...]
  # output {symbol => [symbol, symbol, ...], ...}
  # takes in the rules and generates a hash with the set of
  # terminals that can follow each non-terminal
  def follows(rules)
    to_return = {}
    # set up to_return
    rules.each do |rule|
      to_return[rule.lht] = []
    end

    # get the starts so they dont have to be recalculated each time
    starts = start(rules)

    # call recursive function on each key
    to_return.each_key do |nonterminal|
      to_return[nonterminal] = find_follows_for_symbol(nonterminal, starts, rules)
    end

    to_return
  end

  # contains a Rule and an Integer.
  # the integer is the position, which
  # corresponds to the position the
  # parser is in while processing the rule.
  class RulePos
    attr_reader :rule, :position

    # takes a rule and a position.
    # rule must be a Rule, position is an int
    def initialize(rule, position)
      unless rule.is_a?(Rule) && position.is_a?(Integer)
        raise "invalid init for RulePos: #{rule}, #{position}"
      end
      unless position >= 0 && position <= rule.rhts.length
        raise "position out of bounds: #{rule}, #{position}"
      end

      @rule = rule
      @position = position
    end

    # expands out the RulePos. wrapped by expand(rules)
    # Visited is passed in as [] and used
    # to track visited RulePoses, to prevent infinite looping and invalid grammar
    # returns [RulePos, RulePos, ...]
    def expand_recursive(rules, visited)
      to_return = [self]

      visited = [self] if visited == []

      if next_sym != :complete
        rules.each do |rule|
          if rule.lht == next_sym # if the rule defines the expansion symbol
            new_rule_pos = RulePos.new(rule, 0)

            if visited.include?(new_rule_pos) # if this pair has been encountered
              if position != 0 || rule != rule() # if this is not self-recursion
                # then this is a loop
                raise "ERROR: loop detected in parser grammar: check lexeme '#{next_sym}'"
              end
            else
              to_return << new_rule_pos # it's a valid expansion to add
              expansion = new_rule_pos.expand_recursive(rules, visited + [new_rule_pos])
              to_return = (to_return + expansion).uniq # expand that symbol as well
            end
          end
        end
      end
      to_return
    end

    # expands out the RulePos.
    # returns an array of RulePos that form the valid expansion
    def expand(rules)
      expand_recursive(rules, [])
    end

    # gets the next symbol as referenced by the position
    # in the rule.
    # if at the end of a rule, :complete is returned instead
    def next_sym
      if position == rule.rhts.length # at end of rule
        :complete
      else
        rule.rhts[position]
      end
    end

    def to_s
      "<rule #{rule}>, <position #{position}>"
    end

    def ==(other)
      other.is_a?(RulePos) && other.rule == rule && other.position == position
    end

    # wrapper of ==
    def eql?(other)
      self == other
    end

    def hash
      return to_s.hash
    end
  end

  # input: [rule, rule, ...]
  # generate context data for state 0
  # expands out all the rules for *__FINAL__
  # output: [RulePos, RulePos, ...]
  def state_zero_context(rules)
    to_return = []
    rules.each do |rule|
      to_return << RulePos.new(rule, 0) if rule.lht == :__FINAL__
    end

    intermediate = to_return.clone

    intermediate.each do |rule_pos| # expand each rule w/ position
      to_return += rule_pos.expand(rules) # append the expanded rules
    end

    to_return.uniq # return the full expansion of *__FINAL__
  end

  # contains context information about rule/pos->state mappings
  class RulePosContext
    # sets internal context to empty initial state
    def initialize
      @data = []
    end

    # adds a rulePos for the state
    def add_rule_pos(state, rule_pos)
      # init unless there's already pairs for the state
      data[state] = [] unless data[state].is_a?(Array)
      # append the pair
      data[state] << rule_pos unless data[state].include?(rule_pos)
      nil
    end

    # adds an array of rulePoss to the state
    def add_rule_poss(state, rule_poss)
      # init unless there's already pairs for the state
      data[state] = [] unless data[state].is_a?(Array)
      # append the pairs
      data[state] = data[state] + rule_poss unless data[state].include?(rule_poss)
      nil
    end

    # returns the rule that the current cursor is referencing.
    # ignores position.
    def rule(cursor)
      raise "cursor #{cursor} OOB" unless cursor[:state] < data.length
      raise "cursor #{cursor} OOB" unless cursor[:pair] < data[cursor[:state]].length

      data[cursor[:state]][cursor[:pair]].rule
    end

    # cursor format: ({ state: state #, pair: pair #})
    # return whether the cursor is at the end of the context table
    def more_rules?(cursor)
      if cursor[:state] < data.length - 1
        true
      elsif cursor[:pair] < data.last.length - 1
        true
      else
        false
      end
    end

    # returns the next symbol for the rule/pos pointed to by cursor.
    # returns :complete if at the end of a rule.
    def next_sym(cursor)
      raise "cursor #{cursor} OOB" unless cursor[:state] < data.length
      raise "cursor #{cursor} OOB" unless cursor[:pair] < data[cursor[:state]].length

      data[cursor[:state]][cursor[:pair]].next_sym
    end

    # advance the cursor to the next rule/pos pair,
    # as outlined by the context info.
    def advance(cursor)
      if more_rules?(cursor)
        if cursor[:pair] < data[cursor[:state]].length - 1
          cursor[:pair] += 1
        else
          cursor[:state] += 1
          cursor[:pair] = 0
        end
      else
        cursor = :no_more_pairs
      end
      cursor
    end

    # given a cursor and the rules,
    # returns an array of rposses for the next state
    # cursor's selected rpos must point to a rht that
    # is not at the end of a rule.
    def rposs_for_next_state(cursor, rules)
      to_return = []
      next_sym = next_sym(cursor)
      # find all the rposs pointing to the same symbol
      # as the cursor
      data[cursor[:state]].each do |rule_pos|
        if rule_pos.next_sym == next_sym
          to_return << RulePos.new(rule_pos.rule, rule_pos.position + 1)
        end
      end

      intermediate = to_return.clone

      # expand the new rposs
      intermediate.each do |rule_pos| # expand each rule w/ position
        to_return += rule_pos.expand(rules) # append the expanded rules
      end

      to_return.uniq
    end

    # find the state number of a state
    # with the same rposs as the supplied array
    # return nil if no match
    def next_state(rposs)
      to_return = nil
      data.each_with_index do |rposs_for_a_state, state_num|
        if rposs_for_a_state == rposs # if state matches
          # raise error if a match has already been found
          raise "found duplicate states: #{to_return},#{state_num}" unless to_return.nil?

          # otherwise, to_return is the state found
          to_return = state_num
        end
      end
      to_return
    end

    # creates a new state
    # returns the number of the new state
    def append_state(rposs)
      raise "tried to add new state but found #{rposs.class}" unless rposs.is_a? Array
      
      rposs.each do |rpos|
        raise "tried to add new state but found #{rpos.class} in array" unless rpos.is_a? RulePos
      end

      data << rposs
      data.length - 1
    end

    def to_s
      "< data #{data} >"
    end

    private

    # data is internally implemented as a 2D array of RulePos objects.
    # data[state #][pair #] = RulePos
    attr_accessor :data
  end

  # try to create reduce action for the pair that the cursor is on
  # raise errors if there's a table collision
  def attempt_reduce(table, context, cursor, rules)
    # get the terminals that can follow
    # the completed expression
    follows = follows(rules)[context.rule(cursor).lht]
    follows.each do |follow|
      # get the cell
      cell = table.action(cursor[:state], follow)
      if !cell.type.nil? # cell occupied
        # check that it matches what would be written
        # otherwise error
        raise "ERROR: state #{cursor[:state]},#{follow} #{cell.type}/REDUCE" unless cell.type == :REDUCE
        raise "ERROR: state #{cursor[:state]},#{follow} REDUCE/REDUCE" unless cell.value == context.rule(cursor)
      else # unoccupied
        # write the type and the rule into the cell
        cell.type = :REDUCE
        cell.value = context.rule(cursor)
      end
    end
  end

  # try to create shift action for the pair the cursor is on
  # raise errors if there's a table collision
  def attempt_shift(table, context, cursor, rules)
    next_symbol = context.next_sym(cursor)
    # generate the new set of rulePoses for the state after the shift
    next_state_context = context.rposs_for_next_state(cursor, rules)
    # find the matching state (nil if not found)
    next_state_num = context.next_state(next_state_context)

    if next_state_num.nil? # if there is no matching state
      # create the new state and state # to write to cell
      table.add_row
      next_state_num = context.append_state(next_state_context)
    end

    # get the cell
    cell = table.action(cursor[:state], next_symbol)
    if !cell.type.nil? # cell occupied
      # check that it matches what would be written
      # otherwise error
      raise "ERROR: state #{cursor[:state]},#{next_symbol} #{cell.type}/SHIFT" unless cell.type == :SHIFT
      raise "ERROR: state #{cursor[:state]},#{next_symbol} SHIFT/SHIFT" unless cell.value == next_state_num
    else # cell unoccupied
      # write the type and rule into the cell
      cell.type = :SHIFT
      cell.value = next_state_num
    end
  end

  # try to create goto action for the pair the cursor is on
  # raise errors if there's a table collision
  def attempt_goto(table, context, cursor, rules)
    next_symbol = context.next_sym(cursor)
    # generate the new set of rulePoses for the state after the shift
    next_state_context = context.rposs_for_next_state(cursor, rules)
    # find the matching state (nil if not found)
    next_state_num = context.next_state(next_state_context)

    if next_state_num.nil? # if there is no matching state
      # create the new state and state # to write to cell
      table.add_row
      next_state_num = context.append_state(next_state_context)
    end

    # get the cell
    cell = table.action(cursor[:state], next_symbol)
    if !cell.type.nil? # cell occupied
      # check that it matches what would be written
      # otherwise error
      raise "ERROR: state #{cursor[:state]},#{next_symbol} #{cell.type}/GOTO" unless cell.type == :GOTO
      raise "ERROR: state #{cursor[:state]},#{next_symbol} GOTO/GOTO" unless cell.value == next_state_num
    else # cell unoccupied
      # write the type and rule into the cell
      cell.type = :GOTO
      cell.value = next_state_num
    end
  end

  # input = [rule, rule, ...]
  # output = table
  def generate_table(rules)
    # get the table
    to_return = Table.new(t_syms, nt_syms)

    # track position in rules during table creation
    context = RulePosContext.new
    # state 0 is the start of __FINAL__
    to_return.add_row
    context.add_rule_poss(0, state_zero_context(rules))

    # add special DONE action
    to_return.action(0, :"$").type = :DONE

    # generate rest of table

    # generator start point
    cursor = { state: 0, pair: 0 }
    # while cursor still references a rulePos pair
    while cursor != :no_more_pairs
      # reached end of rule?
      next_sym = context.next_sym(cursor)
      if next_sym == :complete
        attempt_reduce(to_return, context, cursor, rules)
      elsif t_syms.include? next_sym # if next sym is a terminal
        attempt_shift(to_return, context, cursor, rules)
      else # next sym is a non-terminal
        attempt_goto(to_return, context, cursor, rules)
      end
      cursor = context.advance(cursor)
    end
    to_return
  end
end
