require 'template'


class Configuration
  attr_accessor :name, :template, :flags

  def initialize(name, template_name, flags)
    @name = name
    if (template_name != '')
      @template = Template.get(template_name).clone
    else
      @template = Template.new()
    end
    @flags = flags
  end

end