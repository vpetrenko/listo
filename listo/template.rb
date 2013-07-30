require 'const'
require 'utils'

class Template
  include DeepCopy
  include PathContext
  include ActionStorage

  attr_reader  :name

  @@templates = {}

  def Template.has?(name)
    @@templates.key?(name)
  end

  def Template.get(name)
    raise "Template named '#{name}' not found." if !Template.has?(name)
    @@templates[name]
  end

  def Template.each
    @@templates.each do |k,v|
      yield k, v
    end
  end

  def initialize(name, maker)
    raise "Template named '#{name}' already exists." if @@templates.has_key?(name)
    @@templates[name] = self
    @name = name
    @maker = maker
    @path = maker.path
  end


#  def replace_smart(const)
#    raise 'Smart replace work on single const only' unless const.single?
#    name, value = const.single.split('=')
#
#    @consts[const.name].each do |c|
#      if c.single.index(name + '=') == 0
#        c.single = const.single
#      end
#    end
#  end


#  def subs!(dict)
#    @consts.each do |c|
#      c[1].each do |c2|
#        c2.subs!(dict)
#      end
#    end
#  end

 
  def to_s
    result = "Template '#{@name}' {\n"
    @actions.each do |c|
      result += c.to_s + "\n"
    end
    result += '}'
  end
end

