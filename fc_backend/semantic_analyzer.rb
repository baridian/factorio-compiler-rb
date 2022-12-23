# frozen_string_literal: true

# call peephole to run the optimize function over a sliding window
# execution time is <10x slower and almost every line is passed over 10x
module SemanticAnalyzer
  # runs an unesseccary assignment optimization. Further optimizations can be added later
  def self.optimize(file)
    raise "ERROR: expected String type, got #{file.class}" unless file.is_a? String

    # c0:t1=mem+1<-c0
    # counter:mem=t1<-c0
    #                              1        2           3                 4         5        6
    #                             c0    :  t1  =      mem+1          <-  c0      counter :  mem     =t1<-c0
    uneccessary_assignment = /(\w+):(t\d+)=(\w+.*?\w+)<-(c\d+)\n(\w+):(\w+)=\2<-\1/

    file.gsub(uneccessary_assignment) do |matched_string|
      match = matched_string.match uneccessary_assignment
      #  counter  :   mem     =    mem+1  <-    c0
      "#{match[5]}:#{match[6]}=#{match[3]}<-#{match[4]}"
    end
  end
  
  # given intermediate code, return a hash of all circuits with keys for their names
  def self.get_circuits_by_name(file)
    circuits = file.split(/^CRC /)[1..]

    circuits_by_name = {}
    circuits.each do |circuit|
      circuit_name = circuit.match(/\w+/).to_s # since CRC has been chopped off the next word is the name
      circuits_by_name[circuit_name] = circuit
    end

    circuits_by_name
  end

  def self.get_circuit_call_names(circuit)
    this_name = circuit.match(/\w+/).to_s
    circuit_calls = circuit.scan(/INIT [\w|,]+=(\w+)/)
    called_circuits = []
    circuit_calls.each do |circuit_call|
      called_circuits << circuit_call.first
    end

    called_circuits << this_name
  end

  # splits the input intermediate code file up into a series of circuits
  # scans which circuits are called in the last circuit in the file (the main circuit)
  # circuits that aren't called are removed.
  def self.remove_uncalled_circuits(file)
    circuits = file.split(/^CRC /)[1..]

    circuits_by_name = get_circuits_by_name(file)

    called_circuits = [circuits.last]

    visited_circuits = []

    # start with the main circuit
    # add everything it calls to visited
    # then go to those circuits and everything they call to visited
    # loop until no further calls found
    until called_circuits == visited_circuits
      visited_circuits = called_circuits.clone

      visited_circuits.each do |visited_circuit|
        new_names = get_circuit_call_names visited_circuit
        new_names.each do |new_name|
          called_circuits << circuits_by_name[new_name]
        end
      end

      called_circuits.uniq!
    end

    "CRC #{called_circuits.reverse.join("CRC ")}"
  end

  # checks that there aren't undeclared variable names used in a circuit definition
  def self.check_var_names(file)
    error_detected = false
    circuits = file.split(/^CRC /)[1..]

    circuits.each do |circuit|
      circuit_name = circuit.match(/\w+/).to_s

      valid_var_names = []
      valid_names_patterns = [/(?<=INIT )[\w|,]+/, /(?<=ARGS )[\w|,]+/]
      valid_names_patterns.each do |valid_name_pattern|
        file.scan(valid_name_pattern).each do |init_statement|
          valid_var_names += init_statement.split(',')
        end
      end

      statements = circuit.scan(/(?<=:).*?(?=<-)/)
      statements += circuit.scan(/(?<=RET )[\w|,]+/)

      statements.each do |statement|
        compiler_generated_var_name = /t\d+|E/
        number_literal = /\d+/
        terms = statement.scan(/\w+/)

        terms.reject! { |term| term.match? compiler_generated_var_name }

        terms.reject! { |term| term.match? number_literal }

        terms.reject! { |term| valid_var_names.include? term }

        error_detected = true unless terms.empty?

        terms.each do |term|
          puts "variable #{term} in circuit #{circuit_name}"
        end
      end
    end

    raise 'ERROR: one or more uninitialized variables used' if error_detected

    file
  end

  # formats a circuit passed to it
  # calls to circuits are left intact
  # all other circuit wrappings are pulled out
  # need to work out how to properly assign return vals
  def self.format_circuit(input_circuit, rehash = nil, args = nil, return_vals = nil, caller_name = nil)
    circuit = input_circuit.clone
    this_name = if caller_name
                  input_circuit.match(/\w+/).to_s
                else
                  input_circuit.match(/(?<=^CRC )\w+/).to_s
                end

    if rehash && args && return_vals && caller_name
      # do stuff to change the network names

      # add the hash to combinator outputs
      circuit = circuit.split("\n").collect do |line|
        if line.match? ':'
          parts = line.split ':'
          parts[0] = parts[0] + rehash.to_s
          line = parts.join ':'
        end

        if line.match? '<-'
          line += rehash.to_s
        end

        line
      end.join("\n")

      # generate the arguments
      params = input_circuit.match(/(?<=^ARGS )[\w|,]+/).to_s.split ','

      raise "ERROR: wrong number of args for circuit #{this_name}" unless params.length == args.length

      params_enum = params.each

      arg_replacement = args.collect do |arg|
        "#{this_name}#{rehash}:#{params_enum.next}=#{arg}<-#{caller_name}"
      end.join("\n")

      circuit.gsub!(/^.*?ARGS.*?$/, arg_replacement)

      # generate the returns
      to_returns = input_circuit.match(/(?<=^RET )[\w|,]+/).to_s.split ','

      unless to_returns.length == return_vals.length
        raise "ERROR: wrong number of return variables for circuit #{this_name}"
      end

      to_returns_enum = to_returns.each

      return_replacement = return_vals.collect do |return_val|
        "#{caller_name}:#{return_val}=#{to_returns_enum.next}<-#{this_name}#{rehash}"
      end.join("\n")

      circuit.gsub!(/^.*?RET.*?$/, return_replacement)
      circuit = circuit.split("\n")[1..].join("\n")
    elsif rehash || args || return_vals || caller_name
      raise 'ERROR: must pass only circuit or all 4 arguments to format_circuit'
    end

    non_call_init = /^INIT[^=]*$/
    circuit.gsub!(non_call_init, '')

    circuit_args = /^ARGS.*$/
    circuit.gsub!(circuit_args, '')

    ret = /^RET.*$/
    circuit.gsub!(ret, '')

    circuit.split("\n").reject(&:empty?).join("\n")
  end

  # starting from the bottom find all circuit calls
  # expand out the called circuit, taking context about what variables are passed in
  # and where variables are being assigned
  # add in the properly formatted (but still with calls) circuit above
  # remove the call
  # repeat until there are no calls
  def self.flatten_calls(input_file, circuits_by_name)
    file = input_file.clone
    circuit_calls = file.scan(/^INIT.*=.*$/)

    until circuit_calls.empty?

      last_call_pattern = /(.|\n)*\KINIT.*?$/ # TODO: this pattern isnt matching properly

      # find the call pattern that appears last. Split the input into what appears before and after
      # looking through only what appears before, find the last occurence of a circuit name
      # take only the name of it
      caller_name = input_file.split(last_call_pattern).first.match(/(.|\n)*\K^CRC \w+$/).to_s.match(/(?<=CRC )\w+/).to_s

      last_call = circuit_calls.last

      # name of the circuit being called
      calling_name = last_call.match(/(?<==)\w+/).to_s

      reversed_lines = file.lines.reverse

      lines_from_bottom = 0

      lines_from_bottom += 1 until reversed_lines[lines_from_bottom].match(/INIT.*=.*/)

      # the values that are being passed to the circuit
      args = last_call.match(/(?<=\().*?(?=\))/).to_s.split ','

      # where to write the values returned from the circuit
      vals = last_call.match(/(?<=INIT ).*(?==)/).to_s.split ','

      # insert the circuit instance at the top of the file
      file = format_circuit(circuits_by_name[calling_name], lines_from_bottom, args, vals, caller_name) + "\n" + file

      file.gsub! last_call_pattern, ''

      circuit_calls = file.scan(/^INIT.*=.*$/)
    end

    file.gsub! /^CRC.*?$/, ''

    file.split("\n").reject(&:empty?).join("\n")
  end

  # properly format main
  # then expand out main with the flatten function
  # return that string
  def self.expand_circuit_calls_for_file(file)
    circuits = file.split(/^CRC /)[1..]

    main_circuit = "CRC #{circuits.last}"

    to_replace = main_circuit.match(/(?<=CRC )\w+/).to_s

    main_circuit.gsub! "#{to_replace}:", "main:"

    main_circuit.gsub! "<-#{to_replace}", "<-main"

    main_circuit.gsub! "CRC #{to_replace}", "CRC main"

    reformatted = format_circuit(main_circuit)


    flatten_calls(reformatted, get_circuits_by_name(file))
  end
end
