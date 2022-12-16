# frozen_string_literal: true

# the optimizer contains several functions to optimize 
module Optimizer
  self.WINDOW_LENGTH = 20

  def self.optimize(file)
    raise "ERROR: expected String type, got #{file.class}" unless file.is_a? String


  end

  def peephole(file)

  end
end