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
