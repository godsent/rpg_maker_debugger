class Scene_Base
  alias_method :original_update, :update

  def update(*args, &block)
    Debugger.load_console if Input.trigger? Debugger::TRIGGER
    original_update *args, &block
  end
end
