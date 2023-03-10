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
