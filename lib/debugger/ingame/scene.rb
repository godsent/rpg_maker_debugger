class Debugger::Ingame::Scene < Scene_Base
  attr_accessor :evaluater

  def start
    super
    @input = ""
    @cursor_position = 0
    @submitted_inputs = []
    @si_cursor_position = 0
    create_all_windows
    open_all_windows
    print_output(hello_message)
  end

  def quit
    SceneManager.return
  end

  def print_output(message)
    @output_window.print(message)
  end

  def update
    super

    capture_input
    setup_input_window
  end

  private

  def hello_message
    result, _ = evaluater.evaluate("is_a?(Class) ? [self, '.'] : [self.class, '#']")
    klass, separator = result
    method_name, _ = evaluater.evaluate('__method__')

    Debugger::WORDS[:hello] % "#{klass.name}#{separator}#{method_name}"
  end

  def capture_input
    Debugger::KeyboardInput.update

    if Debugger::KeyboardInput.enter?
      handle_enter
    elsif Debugger::KeyboardInput.backspace?
      handle_backspace
    elsif Debugger::KeyboardInput.left?
      handle_left
    elsif Debugger::KeyboardInput.right?
      handle_right
    elsif Debugger::KeyboardInput.up?
      handle_up
    elsif Debugger::KeyboardInput.down?
      handle_down
    elsif Debugger::KeyboardInput.esc?
      handle_esc
    elsif Debugger::KeyboardInput.page_up?
      handle_page_up
    elsif Debugger::KeyboardInput.page_down?
      handle_page_down
    elsif char = Debugger::KeyboardInput.char
      handle_char(char)
    end
  end

  def handle_enter
    evaluate_input
    @submitted_inputs = [@input] + @submitted_inputs unless @input.empty?
    @si_cursor_position = 0
    @cursor_position = 0
    @input = ''
  end

  def handle_backspace
    l = [@cursor_position - 1, 0].max
    r = @cursor_position
    @input = @input[0...l] + @input[r..-1]
    handle_left
  end

  def handle_left
    @cursor_position = [@cursor_position - 1, 0].max
  end

  def handle_right
    @cursor_position = [@cursor_position + 1, @input.size].min
  end

  def handle_up
    set_submitted_input
    @si_cursor_position = [@si_cursor_position + 1, @submitted_inputs.length - 1].min
  end

  def handle_down
    return if @si_cursor_position == 0

    @si_cursor_position = [@si_cursor_position - 1, 0].max
    set_submitted_input
  end

  def handle_esc
    quit
  end

  def handle_page_up
    @output_window.page_up
  end

  def handle_page_down
    @output_window.page_down
  end

  def handle_char(char)
    l = r = @cursor_position
    @input = @input[0...l] + char.to_s + @input[r..-1]
    handle_right
  end

  def set_submitted_input
    @input = @submitted_inputs[@si_cursor_position]
    @cursor_position = @input.length
  end

  def evaluate_input
    print_output("#{Debugger::PROMPTS[:enter]} #{@input}")
    result, error = evaluate

    if error
      print_output("#{Debugger::PROMPTS[:result]} #{error.message}")
    elsif result
      print_output("#{Debugger::PROMPTS[:result]} #{result}")
    end
  end

  def evaluate
    return if @input.empty?

    case  Debugger.handle_signal(@input)
    when :close
      quit
      return Debugger::WORDS[:bye]
    when :continue
      evaluater.reset
      return Debugger::WORDS[:ok]
    end

    evaluater.evaluate(@input)
  end

  def setup_input_window
    @input_window.prompt = prompt
    @input_window.input = @input
    @input_window.cursor_position = @cursor_position
  end

  def create_all_windows
    @input_window = Debugger::Ingame::InputWindow.new
    setup_input_window
    @output_window = Debugger::Ingame::OutputWindow.new
  end

  def prompt
    if @evaluater.idle?
      Debugger::PROMPTS[:enter]
    else
      Debugger::PROMPTS[:continue]
    end
  end

  def open_all_windows
    @input_window.open
    @output_window.open
  end
end
