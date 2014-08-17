class Debugger
  VERSION = '0.0.1'
  WORDS = {
    hello: "debug console activated, version: #{VERSION}",
    bye:   "good bye"
  }
  TRIGGER = Input::F5
  WIN  = {
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
    #Loads Console
    def load_console(binding = Object.__send__(:binding))
      puts WORDS[:hello]   #say hello
      focus Console.window #focus on debug console window
      Console.run(binding) #run with binding
    end

    #methods checks if user input is a signal
    def handle_signal(signal)
      case signal.chop     #remove new line in the end
      when SIGNALS[:close] #when user going to close the console
        close_console
      when SIGNALS[:clear] #when user going to clear eval stack
        Console.clear_eval
        :continue
      end
    end

    private

    #closes console
    def close_console
      puts WORDS[:bye]        #say good bye
      focus GameWindow.window #focus the game window
      sleep 1                 #hack, prevent enter in the game window
      raise StopIteration     #stops loop
    end

    #we have two winows - console and game window
    #method to focuse one of them
    def focus(window)
      WIN[:focus].call window
    end
  end
end

require 'debugger/console'
require 'debugger/game_window'
