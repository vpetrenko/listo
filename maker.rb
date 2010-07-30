$:[$:.length] = 'listo/'

require 'utils'
require 'pathname'
require 'const'


class Maker
  include PathContext
  attr_accessor :current_project

# Constants
#   General
  DEBUG = Flags.new(:DEBUG)
  RELEASE = Flags.new(:RELEASE)

  WIN32_X86 = Flags.new(:WIN32_X86)
  UNIX = Flags.new(:UNIX)

  MSVC = Flags.new(:MSVC)
  GCC = Flags.new(:GCC)

  LIB = Flags.new(:LIB)
  DLL = Flags.new(:DLL)
  APP = Flags.new(:APP)

#   Projects
  OUT_DIR = :OutputDirectory
  TEMP_DIR = :IntermediateDirectory
  INCLUDE_DIRS = :AdditionalIncludeDirectories
  OUT_FILE = :OutputFile
  LIB_DIRS = :AdditionalLibraryDirectories
  DEFINES = :PreprocessorDefinitions
  DEPS = :AdditionalDependencies

  RUNTIME_LIB = :RuntimeLib
  DEBUG_DLL = '3'
  RELEASE_DLL = '2'

  SUBSYS = :SubSys
  SUBSYS_CONSOLE = '1'
  SUBSYS_GUI = '2' 

  DISABLE_LANGUAGE_EXTENSIONS = :DisableLanguageExtensions

#
  CL_ADDIT_OPTIONS = :CL_ADDIT_OPTIONS
  TREAT_WCHAR = :TREAT_WCHAR
  LINK_ADDIT_OPTIONS = :LINK_ADDIT_OPTIONS

# File types
  FILES_CPP = :CPP
  FILES_H = :H
  FILES_DATA = :DATA
  FILES_QRC = :QRC
  FILES_RESOURCES = :RES
  FILES_UI = :ui
  FILES_YAMC = :yamc

#
  PARAM_OUT_DIR = 'OUT_DIR'
  PARAM_CONFIG = 'CONFIG'
  PARAM_PLATFORM = 'PLATFORM'
  PARAM_PROJECT = 'PROJECT'

# Generator
  GENERATOR_TARGET = :GeneratorTarget
  GENERATOR_COMPONENTS_ADD = :GeneratorComponentsAdd
  GENERATOR_COMPONENTS_REMOVE = :GeneratorComponentsRemove

# External API
#   Configuration

  def set_qt_path(path)
    World.log.debug "Set qt_path to '#{path}'."
    World.set_config_variable(:qt_path, path)
  end
  
#   Templates
  def create_template(name)
    @current_template = Template.new(name, self)
    @current_project = nil
    World.log.debug "Create template '#{name}'."
  end

  def template_add(key, *values)
    real_values = [key]
    flags = Flags.new()
    values.each do |v|
      if v.is_a?(Flags)
        flags.add(v)
      elsif v.is_a?(String)
        real_values << v
      end
    end
    @current_template.do(ConstAction::ADD, real_values, flags)
  end

  def template_replace(key, *values)
    real_values = [key]
    flags = Flags.new()
    values.each do |v|
      if v.is_a?(Flags)
        flags.add(v)
      elsif v.is_a?(String)
        real_values << v
      end
    end
    @current_template.do(ConstAction::REPLACE, real_values, flags, self)
  end

  def template_clear(key, *values)
  real_values = [key]
  flags = Flags.new()
  values.each do |v|
    if v.is_a?(Flags)
      flags.add(v)
    end  
  end
    @current_template.do(ConstAction::CLEAR, real_values, flags)
  end

#   Projects
  def create_project(name, additional_path = '')
    @current_template = nil
    @current_project = Project.new(name, self, additional_path)
  end

  def add_project_flags(*flags)
    @current_project.flags.set(flags)
  end

  def filesin(prefix, files)
   	prefix = prefix + '/' if prefix[prefix.length - 1] != '/'[0]
    files = [files].flatten
	files.map! do |f|
		prefix + f
	end
	files
  end

  def fileset(include, exclude)
    World.log.debug "fileset(#{include}, #{exclude})"

    current_path_name = Pathname.new(@current_project.path)
    include, exclude = [include].flatten, [exclude].flatten
    include.map! do |m|
      (current_path_name + m).to_s
    end
    exclude.map! do |m|
      (current_path_name + m).to_s
    end
    exclude << '**/.svn/**/*'
    exclude << '**/_svn/**/*'

    incl_files = Dir.glob(include)
    excl_files = Dir.glob(exclude)
#    puts excl_files 
    result = []
    (incl_files - excl_files).each do |v|
      result << Pathname.new(v).relative_path_from(current_path_name).to_s unless File.directory?(v)
    end
    World.log.debug "end fileset()"
    result
  end

  def add(key, *values)
    real_values = [key]
    flags = Flags.new()
    values.each do |v|
      if v.is_a?(Flags)
        flags.add(v)
      elsif v.is_a?(String)
        real_values << v
      elsif v.is_a?(Array)
        v.each do |vv|
          real_values << vv
        end
      end
    end
    @current_project.do(ConstAction::ADD, real_values, flags)
  end

  def replace(key, *values)
    real_values = [key]
    flags = Flags.new()
    values.each do |v|
      if v.is_a?(Flags)
        flags.add(v)
      elsif v.is_a?(String)
        real_values << v
      elsif v.is_a?(Array)
        v.each do |vv|
          real_values << vv
        end
      end
    end
    @current_project.do(ConstAction::REPLACE, real_values, flags)
  end

  def use_template(name)
    @current_project.do(ConstAction::USE_TEMPLATE, [name], Flags.new()) if @current_project != nil 
    @current_template.do(ConstAction::USE_TEMPLATE, [name], Flags.new()) if @current_template != nil 
  end

  def set_guid(guid)
    @current_project.guid = guid
  end

  def create_config(name, *flags)
    @current_project.add_configuration(Configuration.new(name, Flags.new(flags)))
    self
  end

  def config_add_flags(*flags)
    @current_project.config_add_flags(flags)
  end

  def add_const(name, value)
    @current_project.current_config.template.add(Const.new(name, value, nil, @current_project))
  end

  def replace_const(name, value)
    @current_project.current_config.template.replace(Const.new(name, value, nil, @current_project))
  end

  def replace_const_smart(name, value)
    @current_project.current_config.template.replace_smart(Const.new(name, value, nil, @current_project))
  end

  def set_build_type(build)
    @current_project.current_config.build_type = build
  end

  def add_deps(*deps)
    @current_project.add_deps(deps)
  end

#   Solutions
  def create_solution(name, additional_path = '')
    @current_project = SolutionProject.new(name, self)
  end

  def solution_add(name)
    @current_project.add(name)
  end


#   Instance methods
  def initialize(path)
	@path = path
    @current_template = nil
    @current_project = nil
  end

  def to_s
    'Maker: ' + @path + '  Prefix: ' + path_prefix
  end

# Makers API
#  def new_dep_project(name)
#    @current_project = DepProject.new(name, self)
#  end

end

