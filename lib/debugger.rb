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

require 'debugger/keyboard_input'
require 'debugger/console'
require 'debugger/renderer'
require 'debugger/patch'
require 'debugger/evaluater'
require 'debugger/ingame'
require 'debugger/stack'
