class ConstAction
  attr_reader :action, :params, :flags, :context
  ADD = :add
#  REMOVE = :remove
  REPLACE = :replace
  CLEAR = :clear
#  SET = :set
#  SMART_REPLACE = :smart_replace
  USE_TEMPLATE = :use_template


  def initialize(action, params, flags, context)
    @action = action
    @params = params
    @flags = flags
    @context = context
  end

  def to_s
    result = "#{@action} #{@params.join(' ')} #{@flags} [#{@context.path}]"
  end
end

class Const
  attr_accessor :values, :context
  def initialize(values, context)
    @context = context
    @values = []
    values.each do |v|
      if v.is_a? String
        @values << v.clone
      else
        @values << v
      end
    end

  end

end

class ConstStorage
  attr_accessor :consts
  attr_accessor :path

  def initialize
    @consts = Hash.new()
    @path = ''
  end

  def fill(actions, flags)
    actions.each do |a|
      if (flags.include?(a.flags))
        case a.action
          when ConstAction::ADD
              @consts[a.params[0]] = [] unless @consts.key?(a.params[0])
              @consts[a.params[0]] << Const.new(a.params[1,a.params.length], a.context)
          when ConstAction::REPLACE
              @consts[a.params[0]] = [Const.new(a.params[1,a.params.length], a.context)]
          when ConstAction::CLEAR
              @consts.delete(a.params[0])
          when ConstAction::USE_TEMPLATE
              fill(Template.get(a.params[0]).actions, flags)
          else
            raise "Unexpected action #{a.action}"
        end
      end
    end
#    World.log.debug "#{storage.consts.keys}"
  end

  def postprocess!(dict)
    @consts.each_value do |c|
      c.each do |cc|
      cc.values.each do |v|
        dict.each do |d|
          v.gsub!('<%=' + d[0] + '%>', d[1]) if v.is_a? String
        end  
      end
      end
      end
  end

  def has?(name)
    @consts.key?(name)
  end

  def each_value(name)
#    raise "Constant #{name} is not found." unless @consts.key?(name)
	if @consts.key?(name)
	    @consts[name].each do |c|
    	  yield c
	    end
	end
  end

  def get_array(name)
    result = []
    each_value(name) do |c|
      c.values.each do |v|
        result << v
      end
    end
    result
  end

  def get_paths(name, separator, prefix, postfix = '', quote = '')
    result = ''
    each_value(name) do |c|
      c.values.each do |v|
        raise 'Unexpected empty path' if v.length < 2
        path = v
        if v[0, 1] == '$'
            path = @path + v[1, path.length]
        elsif v[0, 2] == './'
          path = v[2, path.length]
        elsif v[1, 1] == ':' || v[0, 1] == '/'
          path = v
        end
        result += quote + prefix + path + postfix + quote + separator
      end
    end
    if result != ''
      result = result[0, result.length - separator.length]
    end
    result
  end

  def get_path(name, prefix = '', postfix = '', quote = '')
    get_paths(name, '', prefix, postfix, quote)
  end

  def get_decorated_paths(name, separator, prefix = '', postfix = '', quote = '')
    decorate_path(get_paths(name, separator, prefix, postfix, quote))
  end

  def get_decorated_path(name, prefix = '', postfix = '', quote = '')
    get_decorated_paths(name, '', prefix, postfix, quote)
  end

  def get_value(name, prefix = '', postfix = '', quote = '')
    get_values(name, '', prefix, postfix, quote)
  end

  def get_values(name, separator, prefix = '', postfix = '', quote = '')
    result = ''
    each_value(name) do |c|
      c.values.each do |v|
        result += quote + prefix + v + postfix + quote + separator
      end
    end
    if result != ''
      result = result[0, result.length - separator.length]
    end
    result
  end


  def to_s
    @consts.to_s
  end
end


if false

class Const
  attr_reader :name, :values, :flags, :maker

#  STRING = :string
#  DIRECTORY = :dir
#  PATHNAME = :pathname
#  FILENAME = :filename

  @@meta_consts = {}

  def Const.define(name, single, type)
    raise "Const named '#{name}' already defined." if @@meta_consts.key? name
    @@meta_consts[name] = [single, type]
  end

  def Const.[](name)
    raise "Const named '#{name}' undefined." unless @@meta_consts.key? name
    @@meta_consts[name]
  end

  def initialize(name, values, flags, maker)
    @name = name
    @values = values
    @flags = flags
    @maker = maker
  end

  def subs!(dict)
    @values.each do |x|
    end
  end

end
  
define_const(:name => :OUT_DIR, :single => true, :path => true)
define_const(:name => :TEMP_DIR, :single => true, :path => true)
define_const(:name => :INCLUDE_DIRS, :single => false, :path => true)


OUT_DIR = :OutputDirectory
TEMP_DIR = :IntermediateDirectory
INCLUDE_DIRS = :AdditionalIncludeDirectories
OUT_FILE = :OutputFile
LIB_DIRS = :AdditionalLibraryDirectories
DEFINES = :PreprocessorDefinitions
DEPS = :AdditionalDependencies
end

