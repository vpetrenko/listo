$:[$:.length] = 'listo/'

require 'project'
require 'template'
require 'configuration'
require 'vs2005gen'
require 'sln2005gen'
require 'progen'
require 'uuid'

# Global variables
$CURRENT_MAKER = nil

# Constants


# Global functions

#   Templates
$CURRENT_TEMPLATE = nil



#def fg(a,b,h={})
#  if h.key? :flags
#
#  end
#end

#def f(*a)

#end

#f 1, 2, :flags => READ_ONLY, :



# World
class World
# General API
  def initialize
    @makers = []
	@projects = {}
    @slns = []
    @consts = {}
    @configurations = {}

    Flags.define_group(Maker::APP, Maker::LIB, Maker::DLL)
    Flags.define_group(Maker::DEBUG, Maker::RELEASE)
    Flags.define_group(Maker::WIN32_X86, Maker::UNIX)
  end

  def explore
	traverse('.', /.+(\.listo)$/) do	|maker|
      $cpp_prefix = ''
      $cpp = []
      $h_prefix = ''
      $headers = []
	  maker_obj = Maker.new(File.dirname(maker), self)
	  @makers << maker_obj
      maker_source = IO.read(maker)
      maker_obj.instance_eval(maker_source, maker)
#      load maker
	end
  end

  def check
    guids = {}
    @projects.each do |project|
      if project[1].guid == ''
        project[1].guid = UUID.create_random.to_s.upcase!
      end
      if project[1].guid[0, 1] == '{'
        project[1].guid = project[1].guid[1, project[1].guid.length - 2]
      end
      raise "Duplicate guid found in project '#{project[1].name}'" if guids.key?(project[1].guid)
      guids[project[1].guid] = nil
    end

    @projects.each do |project|
      project[1].bind_deps
    end
    @slns.each do |sln|
      sln.bind_deps
    end
  end

  def build
    @projects.each do |project|
      project[1].confs.each do |conf|
        prepare_conf(conf[1], project[1])
      end
      if project[1].flags.has? Maker::QMAKE
        gen_pro = ProGenerator.new
        gen_pro.generate_project(project[1], project[1].path + '/' + project[1].name + '.pro')
      else
        gen = VS2005Generator.new
        gen.generate_project(project[1], project[1].path + '/' + project[1].name + '.vcproj')
      end  
    end
    @slns.each do |sln|
      gen = Sln2005Generator.new
      gen.generate(sln, sln.path + '/' + sln.name + '.sln')
    end
  end

  def prepare_conf(conf, project)
    dict = {'PROJECT' => project.name,
            'CONFIG' => conf.name,
            'PLATFORM' => 'win32-x86'}
    conf.template.subs!(dict)
  end

  def param_subs!(string, name, value)
    string.gsub!('<%=' + name + '%>', value)
  end

  def check_platform(platform)
    raise "Unexpected platform #{platform}." if !@platforms.key?(platform)
  end

  def add_const(name, value)
    @consts[name] = value
  end

  def add_configuration(configuration)
    @configurations[configuration.name] = configuration
  end

  def add_project(project)
    raise "Project '#{project.name}' already exists in the World." if @projects.key?(project.name)
    @projects[project.name] = project
  end

  def add_sln_project(project)
    @slns << project
  end

  def get_project(name)
    raise "Project '#{name}' not found in the World." if !@projects.key?(name)
    @projects[name]
  end

  def get_configuration(name)
    @configurations[name]
  end
end
