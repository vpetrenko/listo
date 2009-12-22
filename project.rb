$:[$:.length] = 'listo/'

require 'utils'
require 'pathname'


class Project
  attr_reader :name
  attr_accessor :confs
  attr_reader :template_name
  attr_reader :current_config
  attr_reader :name
  attr_accessor :flags

  def initialize(maker, name, additional_path)
    @maker = maker
    @name = name
    @path = Pathname.new(maker.path) + additional_path
    @flags = Flags.new
    @confs = {}
    @template_name = ''
    @current_config = nil
  end

  def use_template(name)
    @template_name = name
  end

  def add_configuration(conf)
    @confs[conf.name] = conf
    @current_config = conf
  end

  def path
	@path.to_s
  end

  def path_prefix
	'../' * @path.to_s.count('/')
  end

  def rev_path_prefix
    path_prefix.gsub('/', '\\')
  end
  
end

class SourceProject < Project
#  attr_accessor :relative_path
  attr_reader :cpp_sources, :h_sources, :data_sources
  attr_accessor :gen_target
  attr_accessor :guid
  attr_reader :dep_projects

  def initialize(maker, name, additional_path)
    super(maker, name, additional_path)
    @cpp_sources = []
    @h_sources = []
    @data_sources = []
    @deps = []
    @dep_projects = []
    @guid = ''
    @maker.world.add_project(self)
  end
  
  def to_s
	'Project ' + name + '  rel: ' + path + '  pref: ' + path_prefix
  end
  
  def inspect
    result = 'deps: '
    @deps.each {|x| result += "\n\t" + x}
    result += "\n.h: "
    @h_sources.each {|x| result += "\n\t" + x}
    result += "\n.cpp: "
    @cpp_sources.each {|x| result += "\n\t" + x}
	result += "\nattrs: " +	attributes_to_s
	result
  end

  def add_cpp_sources(cpp_sources)
   cpp_sources.each {|x| @cpp_sources << Pathname.new(x).relative_path_from(Pathname.new(path)).to_s}
  end

  def add_h_sources(h_sources)
   h_sources.each {|x| @h_sources << Pathname.new(x).relative_path_from(Pathname.new(path)).to_s}
  end

  def add_data_sources(data)
    data.each {|x| @data_sources << x}
  end
  
  def add_deps(deps)
    deps.each {|x| @deps << x}
  end

  def bind_deps
    @deps.each do |d|
      @dep_projects << @maker.world.get_project(d)
    end
  end

end

class SolutionProject < Project
  attr_accessor :projects
  
  def initialize(maker, name, additional_path)
    super(maker, name, additional_path)
    @project_names = []
    @projects = []
    @maker.world.add_sln_project(self)
  end

  def add(name)
    @project_names << name
  end

  def bind_deps
    @project_names.each do |p|
      @projects << @maker.world.get_project(p)
    end
  end

end

class Maker
  attr_accessor :path, :current_project, :world

# Constants
#   General
  DEBUG = 'DEBUG'
  RELEASE = 'RELEASE'

  WIN32_X86 = 'WIN32_X86'
  UNIX = 'UNIX'

  LIB = 'LIB'
  DLL = 'DLL'
  APP = 'APP'

  QMAKE = :qmake

#   Projects
  OUT_DIR = :OutputDirectory
  TEMP_DIR = :IntermediateDirectory
  INCLUDE_DIRS = :AdditionalIncludeDirectories
  OUT_FILE = :OutputFile
  LIB_DIRS = :AdditionalLibraryDirectories
  DEFINES = :PreprocessorDefinitions
  DEPS = :AdditionalDependencies

  PARAM_OUT_DIR = 'OUT_DIR'
  PARAM_CONFIG = 'CONFIG'
  PARAM_PLATFORM = 'PLATFORM'
  PARAM_PROJECT = 'PROJECT'

#   Qt specific
  QT_QT = 'QT += '
  QT_QT_ = 'QT -= '
  QT_TEMPLATE = 'TEMPLATE'
  QT_CONFIG = 'CONFIG'

# External API
#   Configuration
  def set_qt_path(path)
    @world.set_config_variable(:qt_path, path)
  end
  
#   Templates
  def create_template(name)
    @current_template = Template.new(name)
  end

  def template_add(key, values, *flags)
    @current_template.add(Const.new(key, values, Flags.new(flags)))
  end

#   Projects
  def create_project(name, additional_path = '')
    @current_project = SourceProject.new(self, name, additional_path)
  end

  def add_project_flags(*flags)
    @current_project.flags.set(flags)
  end

  def add_cpp_files(path, include = nil, exclude = nil)
    @current_project.add_cpp_sources(FileSet.cpp(Pathname.new(@current_project.path) + path, include, exclude).files)
  end

  def add_h_files(path, include = nil, exclude = nil)
    @current_project.add_h_sources(FileSet.h(Pathname.new(@current_project.path) + path, include, exclude).files)
  end

  def add_cpp_file(path)
    @current_project.add_cpp_sources([Pathname.new(@current_project.path) + path])
  end

  def use_template(name)
    @current_project.use_template(name)
  end

  def set_guid(guid)
    @current_project.guid = guid
  end

  def create_config(name, *flags)
    @current_project.add_configuration(Configuration.new(name, @current_project.template_name, Flags.new(flags)))
  end

  def add_const(name, value)
    @current_project.current_config.template.add(Const.new(name, value))
  end

  def replace_const(name, value)
    @current_project.current_config.template.replace(Const.new(name, value))
  end

  def replace_const_smart(name, value)
    @current_project.current_config.template.replace_smart(Const.new(name, value))
  end

  def set_build_type(build)
    @current_project.current_config.build_type = build
  end

  def add_deps(*deps)
    @current_project.add_deps(deps)
  end

#   Solutions
  def create_solution(name, additional_path = '')
    @current_project = SolutionProject.new(self, name, additional_path)
  end

  def solution_add(name)
    @current_project.add(name)
  end


#   Instance methods
  def initialize(path, world)
	@path = path
    @world = world
    @current_project = nil
    @current_template = nil
  end

  def to_s
    'Maker: ' + @path + '  Prefix: ' + path_prefix
  end

# Makers API
#  def new_dep_project(name)
#    @current_project = DepProject.new(name, self)
#  end

end

