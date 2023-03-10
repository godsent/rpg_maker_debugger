class Debugger::Evaluater
  def initialize(binding)
    @binding = binding
    reset
  end

  # evals code
  def evaluate(code)
    @to_eval << code # add code to stack
    result = eval(@to_eval, @binding) # evals code
    reset
    [result, nil]
  rescue SyntaxError => e # when sytax error happens do not clear stack
    [nil, nil]
  rescue Exception => e # clear stack
    reset
    [nil, e]
  end

  def reset
    @to_eval = ""
  end

  def idle?
    @to_eval.empty?
  end
end
