# lexical analyzer.
# pulls lex rules from lexdefs.txt
class Lex
  def parse_lex_rules_file(file)
    lines = file.split("\n")
    lines.each do |line|
      rules_hash[line.match(/\w+(?==)/).to_s] = Regexp.new line.match(/(?<==\/).*(?=\/\w*$)/).to_s
    end
  end

  public
  def initialize(file)
    @rules_hash = {}
    @rules = []

    @rules_hash = parse_lex_rules_file(file)
    @rules = @rules_hash.keys
  end
end