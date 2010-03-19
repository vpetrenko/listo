$:[$:.length] = 'listo/'

require 'project'
require 'maker'
require 'template'
require 'vs2005gen'
require 'sln2005gen'
require 'progen'
require 'uuid'
require 'logger'


# Global variables

# Constants


# Global functions

#   Templates


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
  @@config = {}
  @@loger = Logger.new(STDOUT)


  def initialize
    @makers = []
    @projects = {}
    @slns = []
    @@world = self
    @@loger.level = Logger::INFO
  end

  def run
    explore
    check
    build
  end

  def explore
    World.log.debug "Starting explore()"

    traverse_listo = lambda do |include, exclude|
      include, exclude = [include].flatten, [exclude].flatten
      exclude << '**/.svn/**/*'
      exclude << '**/_svn/**/*'

      incl_files = Dir.glob(include)
      excl_files = Dir.glob(exclude)
  #    puts excl_files
      result = []
      res = incl_files - excl_files
      res.each do |v|
        result << v unless File.directory?(v)
      end
      result
    end

    traverse_listo.call('./**/*.listo', './source/3rd/**/*').each do	|maker|
      maker_obj = Maker.new(File.dirname(maker))
      World.log.debug "Found listo file '#{maker}'."
      @makers << maker_obj
      maker_source = IO.read(maker)
      maker_obj.instance_eval(maker_source, maker)
    end
  end

  def view_templates
    Template.each do |name, t|
      puts t.to_s
    end
  end

  def view_projects
    @projects.each_value do |p|
      puts p
    end
  end

  def check
    World.log.debug "Starting check()"
    guids = {}
    @projects.each do |project|
      if project[1].guid == ''
        project[1].guid = UUID.create_sha1(project[1].name, UUID.parse('32CA84C8-B9B7-431d-9821-7A7D5921BEC4')).to_s.upcase!
      end
      if project[1].guid[0, 1] == '{'
        project[1].guid = project[1].guid[1, project[1].guid.length - 2]
      end
      raise "Duplicate guid found in project '#{project[1].name}'" if guids.key?(project[1].guid)
      guids[project[1].guid] = nil
    end

    if false
      @projects.each_value do |project|
        project.confs.each_value do |conf|
          flags = Flags.new()
          flags.add(project.flags)
          flags.add(conf.flags)
          flags.add(Maker::WIN32_X86)
          conf.fill_storage(flags)
          puts "#{project.name} - #{conf.name} #{conf.storage}"
        end
      end
    end

    @projects.each_value do |project|
      project.bind_deps
      World.log.debug "#{project.name} deps: #{project.print_deps}"
    end

    @slns.each do |sln|
      sln.bind_deps
    end
  end

  def build
    World.log.debug "Starting build msvs2005"
    @projects.each_value do |project|
#      if project.flags.has? Maker::QMAKE
#        gen_pro = ProGenerator.new
#        gen_pro.generate_project(project, project.path + '/' + project.name + '.pro')
#      else
        gen = VS2005Generator.new(project)
        gen.generate_project(project, project.path + '/' + project.name + '.vcproj')
#      end
    end
    @slns.each do |sln|
      gen = Sln2005Generator.new
      gen.generate(sln, sln.path + '/' + sln.name + '.sln')
    end
  end

  def build_pro
    World.log.debug "Starting build pro"
    @projects.each_value do |project|
      gen_pro = ProGenerator.new
      gen_pro.generate_project(project, project.path + '/' + project.name + '.pro')
    end
    @slns.each do |sln|
      gen = Sln2005Generator.new
      gen.generate(sln, sln.path + '/' + sln.name + '.sln')
    end
  end

  def self.set_config_variable(name, value)
    case name
      when :qt_path
      else
      raise "Unexpected configuration variable setting '#{name}'"
    end
    @@config[name] = value
  end

  def self.get_config_variable(name)
    if @@config.key?(name)
      return @@config[name]
    else
      case name
        when :qt_path
	  qt_path = find_qt_path
          if qt_path != nil
            @@config[:qt_path] = qt_path
            return qt_path
          else
            raise "Could not determine QT path"
          end
        else
          raise "Unexpected configuration variable getting '#{name}'"
      end
    end
  end

  def self.log
    @@loger
  end

  def self.instance
    @@world
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

  def project_count
    @projects.length
  end

  def World.postprocess_storage(project, configuration, storage)
    dict = {'PROJECT' => project.name,
            'CONFIG' => configuration.name,
            'PLATFORM' => 'win32-x86',
            'QTDIR' => World.get_config_variable(:qt_path)}
    storage.postprocess!(dict)
  end

  def check_platform(platform)
    raise "Unexpected platform #{platform}." if !@platforms.key?(platform)
  end
  
end
