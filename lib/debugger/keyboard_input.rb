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
