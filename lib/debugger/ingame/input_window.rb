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
