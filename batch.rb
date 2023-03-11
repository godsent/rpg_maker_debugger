#gems/rpg_maker_debugger/lib/debugger.rb
class Debugger
  VERSION = '1.0.0.pre'
  MODES = { console: :console, ingame: :ingame }
  CURRENT_MODE = MODES[:ingame]
  WORDS = {
    hello: "Debug console activated from %s, version: #{VERSION}",
    bye:   "good bye",
    ok: "OK"
  }
  TRIGGER = Input::F5
  WIN = {
    focus:     Win32API.new('user32', 'BringWindowToTop', 'I', 'I'),
    find:      Win32API.new('user32', 'FindWindow', 'PP', 'I'),
    get_title: Win32API.new('kernel32', 'GetConsoleTitle', 'PI', 'I'),
  }
  PROMPTS = {
    result:   "=> ",
    enter:    "> ",
    continue: "* "
  }
  SIGNALS = {
    close: 'exit',
    clear: 'clear_eval'
  }
  CLOSE_SIGNAL = 'exit'

  class << self
    def render(binding, render_constants = false)
      Renderer.render binding, render_constants
    end

    # Loads Console
    def load_console(binding = Object.__send__(:binding))
      case CURRENT_MODE
      when MODES[:console]
        say_hello binding
        focus debug_console_window # focus on debug console window
        Console.run(binding) # run with binding
      when MODES[:ingame]
        Debugger::Ingame::Runner.run(binding)
      end
    end

    # methods checks if user input is a signal
    def handle_signal(signal)
      case CURRENT_MODE
      when MODES[:console]
        handle_console_signal(signal)
      when MODES[:ingame]
        handle_ingame_signal(signal)
      end
    end

    private

    def handle_console_signal(signal)
      case signal.strip    # remove new line in the end
      when SIGNALS[:close] # when user going to close the console
        close_console
        :close
      when SIGNALS[:clear] # when user going to clear eval stack
        Console.clear_eval
        :continue
      end
    end

    def handle_ingame_signal(signal)
      case signal.strip    # remove new line in the end
      when SIGNALS[:close] # when user going to close the console
        :close
      when SIGNALS[:clear] # when user going to clear eval stack
        :continue
      end
    end

    def debug_console_window
      title = ("\0" * 256)
                .tap { |buff| WIN[:get_title].call(buff, buff.length - 1) }
                .gsub("\0", '')

      WIN[:find].call 'ConsoleWindowClass', title
    end

    def say_hello(binding) # greeting words
      klass, separator = binding.eval "is_a?(Class) ? [self, '.'] : [self.class, '#']"
      method_name      = binding.eval '__method__'

      puts WORDS[:hello] % "#{klass.name}#{separator}#{method_name}"
    end

    # closes console
    def close_console
      puts WORDS[:bye]        # say good bye
      focus game_window       # focus the game window
      Console.close
      sleep 1                 # hack, prevent enter in the game window
      raise StopIteration     # stops loop
    end

    def game_window
      WIN[:find].call 'RGSS Player', game_title
    end

    def game_title
      @game_title ||= load_data('Data/System.rvdata2').game_title
    end

    # we have two winows - console and game window
    # method to focuse one of them
    def focus(window)
      WIN[:focus].call window
    end
  end
end

#gems/rpg_maker_debugger/lib/debugger/keyboard_input.rb
class Debugger::KeyboardInput
  GET_KEY_STATE = Win32API.new("user32","GetKeyState", 'i', 'i')

  # Key codes
  NUMBERS = 48..57
  LETTERS = 65..90
  SYMBOLS_1 = 186..192
  SYMBOLS_2 = 219..222
  SHIFT = 16 # both right and left
  BACKSPACE = 8
  ENTER = 13
  CAPS = 20
  WHITESPACE = 32
  LEFT = 37
  RIGHT = 39
  UP = 38
  DOWN = 40
  ESC = 27
  PAGE_UP = 33
  PAGE_DOWN = 34

  # Timers
  PRESSED = 30
  EAGER = -3

  class << self
    def update
      instance.update
    end

    [:char, :backspace?, :enter?, :left?, :right?,
     :up?, :down?, :esc?, :page_up?, :page_down?].each do |name|
      define_method(name) { instance.public_send(name) }
    end

    private

    def instance
      @instance ||= new
    end
  end

  def initialize
    @keys = Array.new(256, 0)
  end

  def update
    read_keyboard_keys
  end

  def char
    256.times do |i|
      if key?(i)
        candidate = to_char(i)
        return candidate if candidate
      end
    end

    nil
  end

  {
    backspace?: BACKSPACE,
    enter?: ENTER,
    left?: LEFT,
    right?: RIGHT,
    up?: UP,
    down?: DOWN,
    esc?: ESC,
    page_up?: PAGE_UP,
    page_down?: PAGE_DOWN
  }.each do |name, const|
    define_method(name) { key?(const) }
  end

  private

  def read_keyboard_keys
    256.times do |i|
      @keys[i] = if !pressed32?(i)
                   0
                 elsif @keys[i] == 0 # first press
                   PRESSED
                 elsif @keys[i] == 3  || # user is eager, pressed key and holds it
                       @keys[i] == -1    # user is still eager, still holds the key
                   EAGER # negative timer to distinguish it from positive timer,
                         # mark key as beeing pressed long time
                 elsif @keys[i] < 0 # increment eager (negative) timer
                   @keys[i] += 1
                 else
                   @keys[i] - 1 # decriment positive (not eager) timer
                 end
    end
  end

  def key?(i)
    @keys[i] == PRESSED || @keys[i] == EAGER
  end

  def to_char(i)
    case i
    when NUMBERS
      result = i - 48
      shifted? ? ')!@#$%^&*('[result] : result
    when LETTERS
      result = "abcdefghijklmnopqrstuvwxyz"[i - 65]

      if (caps? || shifted?) && !(caps? && shifted?)
        result.upcase
      else
        result
      end
    when SYMBOLS_1
      if shifted?
        ':+<_>?~'
      else
        ';=,-./`'
      end[i - 186]
    when SYMBOLS_2
      if shifted?
         '{|}"'
      else
        '[\\]\''
      end[i - 219]
    when WHITESPACE
      ' '
    end
  end

  def shifted?
    @keys[SHIFT] != 0
  end

  def caps?
    get_key_state(CAPS) == 1
  end

  def pressed32?(i)
    state = get_key_state(i)
    state != 0 && state != 1
  end

  def get_key_state(i)
    GET_KEY_STATE.call(i)
  end
end
#gems/rpg_maker_debugger/lib/debugger/console.rb
class Debugger
  class Console
    class << self
      # runs console
      def run(binding)
        @current_instance = new binding # initialize new instance and store it
        @current_instance.run           # run new console instance
      end

      # clears eval stack
      def clear_eval
        @current_instance.clear_eval
      end

      def close
        @current_instance = nil
      end
    end

    def initialize(binding)
      @binding = binding # store binding
      clear_eval         # clear eval stack (set it to empty string)
    end

    # sets eval stack to empty string
    def clear_eval
      @to_eval = ''
    end

    # eval loop
    def run
      loop do
        prompt # prints prompt to enter command
        gets.tap do |code| # gets - returns user's input
          evaluate(code) unless code.nil? || Debugger.handle_signal(code) == :continue # evaluate code
        end
      end
    end

    private

    # prints prompt
    def prompt
      if @to_eval != ''
        Debugger::PROMPTS[:continue] # when eval stack is not empty
      else
        Debugger::PROMPTS[:enter]    # when eval stack is empty
      end.tap { |string| print string }
    end

    # evals code
    def evaluate(code)
      @to_eval << code # add code to stack
      result(eval @to_eval, @binding) # evals code
    rescue SyntaxError # when sytax error happens do nothing (do not clear stack)
    rescue Exception => e # return error to the console
      puts e.message
      clear_eval
    end

    # clears eval stack and prints result
    def result(res)
      clear_eval
      puts Debugger::PROMPTS[:result] + res.to_s
    end
  end
end
#gems/rpg_maker_debugger/lib/debugger/renderer.rb
class Debugger
  class Renderer
    FILE_NAME = 'debugger.txt'

    def self.render(binding, include_constants = false)
      new(binding, include_constants).render
    end

    def initialize(binding, include_constants)
      @binding, @include_constants = binding, include_constants
    end

    def render
      in_file do |file|
        keys.each do |key|
          write key, file
        end
      end
    end

    def keys
      arr = %w(local_variables instance_variables)
      @include_constants ? arr + ['self.class.constants'] : arr
    end

    def in_file
      File.open(File.join(Dir.pwd, FILE_NAME), 'a') { |file| yield file }
    end

    def write(key, file)
      @binding.eval(key).map do |element|
        "#{element} => #{@binding.eval(element.to_s)}"
      end.tap do |result|
        file.puts "#{key}:"
        file.puts result
        file.puts
      end
    end
  end
end
#gems/rpg_maker_debugger/lib/debugger/patch.rb
module Debugger::Patch
end

#gems/rpg_maker_debugger/lib/debugger/patch/binding_patch.rb
class Binding
  def bug
    Debugger.load_console self
  end
end
#gems/rpg_maker_debugger/lib/debugger/patch/scene_base_patch.rb
class Scene_Base
  alias_method :original_update_basic_for_debugger, :update_basic

  def update_basic(*args, &block)
    Debugger.load_console if Input.trigger? Debugger::TRIGGER
    original_update_basic_for_debugger *args, &block
  end
end
#gems/rpg_maker_debugger/lib/debugger/evaluater.rb
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
#gems/rpg_maker_debugger/lib/debugger/ingame.rb
module Debugger::Ingame; end

#gems/rpg_maker_debugger/lib/debugger/ingame/concerns.rb
module Debugger::Ingame::Concerns; end

#gems/rpg_maker_debugger/lib/debugger/ingame/concerns/text_drawer.rb
module Debugger::Ingame::Concerns::TextDrawer
  DEFAULT_FONT_SIZE = 22

  def draw_debug_text(x, y, text, font_size = DEFAULT_FONT_SIZE)
    contents.font.size = font_size
    size = text_size(text)
    draw_text(x, y, size.width * 2, size.height, text)
  end
end
#gems/rpg_maker_debugger/lib/debugger/ingame/input_window.rb
class Debugger::Ingame::InputWindow < Window_Base
  CURSOR_FREQ = 40

  include Debugger::Ingame::Concerns::TextDrawer

  def initialize
    super(0, window_y, window_width, window_height)
    self.z = 400
    self.openness = 0
    @cursor_visible = true
    @cursor_position = 0
    @refresh_needed = true
    @updated = 0
    @prompt = "@"
    @input = ""
  end

  def window_width
    Graphics.width
  end

  def window_height
    fitting_height(1)
  end

  def window_y
    Graphics.height - window_height
  end

  def input=(new_input)
    return if @input == new_input

    @input = new_input
    @refresh_needed = true
  end

  def cursor_position=(new_cursor_position)
    return if @cursor_position == new_cursor_position

    @cursor_position = new_cursor_position
    @refresh_needed = true
  end

  def prompt=(new_prompt)
    return if @prompt == new_prompt

    @prompt = new_prompt
    @refresh_needed = true
  end

  def update
    super
    update_cursor_state
    refresh_input
    @updated += 1
  end

  private

  def update_cursor_state
    return unless @updated % CURSOR_FREQ == 0

    @cursor_visible = !@cursor_visible
    @refresh_needed = true
  end

  def refresh_input
    return unless @refresh_needed

    contents.clear
    draw_prompt
    draw_input
    draw_cursor

    @refresh_needed = false
  end

  def draw_prompt
    draw_debug_text(0, 0, @prompt)
  end

  def draw_input
    draw_debug_text(prompt_width, 0, displayable_input)
  end

  def displayable_input
    result = ""
    max_width = contents.width - prompt_width - cursor_width

    @input.chars.to_a.reverse.each do |char|
      break if text_size(result).width >= max_width

      result = char + result
    end

    result
  end

  def prompt_width
    16
  end

  def cursor_width
    16
  end

  def draw_cursor
    cursor_x = prompt_width + text_size(displayable_input[0...@cursor_position]).width
    draw_debug_text(cursor_x, 0, cursor) if @cursor_visible
  end

  def cursor
    '_'
  end
end
#gems/rpg_maker_debugger/lib/debugger/ingame/output_window.rb
class Debugger::Ingame::OutputWindow < Window_Base
  include Debugger::Ingame::Concerns::TextDrawer
  attr_writer :page_index

  def initialize
    super(0, 0, window_width, window_height)
    self.z = 400
    self.openness = 0
    @output = []
    @page_index = 0
  end

  def window_width
    Graphics.width
  end

  def window_height
    Graphics.height - fitting_height(1)
  end

  def print(text)
    @output += split_text_to_lines(text)
    refresh_output
  end

  def page_up
    @page_index = [@page_index + 1, pages.count - 1].min
    refresh_output
  end

  def page_down
    @page_index = [@page_index - 1, 0].max
    refresh_output
  end

  private

  def split_text_to_lines(text)
    result = []
    current_line = ""
    text.split.each do |word|
      candidate = "#{current_line} #{word}".strip

      if text_size(candidate).width > contents.width
        result << current_line
        current_line = word
      else
        current_line = candidate
      end
    end

    result << current_line unless current_line.empty?
    result
  end

  def refresh_output
    contents.clear

    current_page.reverse.each_with_index do |line, i|
      draw_debug_text(0, (max_lines_count - i - 1) * line_height, line)
    end
  end

  def current_page
    pages[@page_index].reverse
  end

  def pages
    @output.reverse.each_slice(max_lines_count).to_a
  end

  def max_lines_count
    contents.height / line_height
  end
end
#gems/rpg_maker_debugger/lib/debugger/ingame/scene.rb
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
#gems/rpg_maker_debugger/lib/debugger/ingame/runner.rb
class Debugger::Ingame::Runner
  def self.run(binding)
    @current_instance = new(binding)
    @current_instance.run
  end

  def initialize(binding)
    @evaluater = Debugger::Evaluater.new(binding)
  end

  def run
    SceneManager.call(Debugger::Ingame::Scene)
    @scene = SceneManager.scene
    @scene.evaluater = @evaluater
  end
end
#gems/rpg_maker_debugger/lib/debugger/stack.rb
# скопировано у DeadElf79
# код, ставящий в соответствие номеру скрипта его название
if RUBY_VERSION.to_f==1.9
  scripts=load_data('Data/Scripts.rvdata2')
else
  scripts=load_data('Data/Scripts.rxdata')
end
$script_names=[]
scripts.each{ |item|
	if RUBY_VERSION.to_f==1.9
		$script_names+=[item[1]]
	else
		text=item.to_s.match(/[\d]+([\w_\d]+)/)[1]
		$script_names+=[ text.gsub(/x$/){''} ]
	end
}


module Kernel

	def call_stack
		stack = caller
		stack.each {|line|
			# skip first lines connected to debugger itself
			next if line =~ /\/lib\/debugger/
			line.gsub!(/\{(\d+)\}/) {|s| $script_names[$1.to_i] + " " }
			p line
		}
		return nil
	end

end
