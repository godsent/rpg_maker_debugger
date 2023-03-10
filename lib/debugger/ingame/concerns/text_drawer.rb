module Debugger::Ingame::Concerns::TextDrawer
  DEFAULT_FONT_SIZE = 22

  def draw_debug_text(x, y, text, font_size = DEFAULT_FONT_SIZE)
    contents.font.size = font_size
    size = text_size(text)
    draw_text(x, y, size.width * 2, size.height, text)
  end
end
