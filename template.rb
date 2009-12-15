require 'utils'

class Const
  attr_accessor :name, :value, :flags

  def initialize(name, value, flags = nil)
    @name = name
    @value = value
    if flags == nil
      @flags = Flags.new()
    else
      @flags = flags
    end
  end

  def single?
    @value.class == String
  end

  def single
    @value
  end

  def single=(val)
    @value = val
  end

  def subs!(dict)
    if single?
      dict.each do |d|
        @value.gsub!('<%=' + d[0] + '%>', d[1])
      end
    else
      @value.each do |x|
        dict.each do |d|
          x.gsub!('<%=' + d[0] + '%>', d[1])
        end
      end
    end
  end

  def value(separator = '', prefix = '', postfix = '', quote = '')
    result = ''
    if single?
      result = quote + prefix + @value + postfix + quote
    else
      result = @value.inject("") { |memo, obj| memo + quote + prefix + obj + postfix + quote + separator}
#      @value.each do |x|
#        result = result +
#      end
      result = result[0, result.length - separator.length]
    end
    result
  end

  def to_s
    "(#{@name}, #{value(' ')}, #{@flags})"
  end
end

class Template
  include DeepCopy
  attr_accessor :consts, :name

  @@templates = {}

  def Template.has?(name)
    @@templates.key?(name)
  end

  def Template.get(name)
    raise "Template named '#{name}' not found." if !Template.has?(name)
    @@templates[name]
  end

  def initialize(name)
    raise "Template named '#{name}' already exists." if @@templates.has_key?(name)
    @@templates[name] = self
    @name = name
    @consts = {}
  end

  def has?(name)
    @consts.key?(name)
  end

  def get(name)
    if has?(name)
      @consts[name]
    else
      nil
    end
  end

  def add(const)
    @consts[const.name] = [] unless has?(const.name)
    @consts[const.name] << const
  end

  def set(const)
    raise "Constant with name #{const.name} already exists." if has?(const.name)
    replace(const)
  end

  def replace(const)
    @consts[const.name] = [const]
  end

  def replace_smart(const)
    raise 'Smart replace work on single const only' unless const.single?
    name, value = const.single.split('=')

    @consts[const.name].each do |c|
      if c.single.index(name + '=') == 0
        c.single = const.single
      end
    end
  end

  def delete(name)
    if has?(name)
      @consts.delete(name)
      true
    else
      false
    end
  end

  def subs!(dict)
    @consts.each do |c|
      c[1].each do |c2|
        c2.subs!(dict)
      end
    end
  end

  def format_single(name, flags = nil, prefix = '', postfix = '', quote = '')
    result = ''
    raise "Constant named '#{name}' not found." unless has?(name)
    @consts[name].each do |c|
      if (c.flags.match?(flags))
        raise "Constant named '#{name}' isn't single value." unless result.empty?
        result += c.value('', prefix, postfix, quote)
      end
    end
    result
#    raise "Constant named '#{name}' isn't single value." if @consts[name].length != 1
#    @consts[name][0].value('', prefix, postfix, quote)
  end

  def format(name, flags = nil, separator = '', prefix = '', postfix = '', quote = '')
    raise "Constant #{name} is not found." unless has?(name)
    result = ''
    @consts[name].each do |c|
      if (c.flags.match?(flags))
        result += c.value(separator, prefix, postfix, quote) + separator
      end
    end
    if result != ''
      result = result[0, result.length - separator.length]
    end
    result
  end

  def to_s
    result = "{\n"
    @consts.each do |c|
      result += "#{c[0]} => ["
      result += c[1].join(' ')
      result += "],\n"
    end
    result += '}'
  end
end
