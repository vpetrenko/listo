$:[$:.length] = 'listo/'

require 'utils'
require 'pathname'

class Project
  include PathContext
  include ActionStorage

  attr_reader :name
  attr_accessor :guid
  attr_accessor :configurations, :flags

  attr_reader :deps
  attr_reader :dep_projects

  def initialize(name, maker, additional_path)
    @name, @maker = name, maker
    @path = Pathname.new(maker.path) + additional_path
    @flags = Flags.new
    @configurations = {}

    @deps = []
    @dep_projects = []
    @guid = ''
    World.instance.add_project(self)
  end

  def add_configuration(conf)
    @configurations[conf.name] = conf
  end

  def to_s
    result = "Project '#{@name}' {\n"
    @actions.each do |c|
      result += c.to_s + "\n"
    end
    result += '}'
  end
  
  def inspect
    result = 'deps: '
    @deps.each {|x| result += "\n\t" + x}
	result
  end

  def add_deps(deps)
    deps.each {|x| @deps << x}
  end

  def deps_for_gcc
    @layers = []
    deps.each {|p| order_help(World.instance.get_project(p))}
    @layers.uniq!
    @layers.reverse! if @layers.size > 0
#    puts @layers.collect {|l| l.name}.join(' ')
    @layers
  end

  private
  def order_help(project)
    project.deps.each { |p|
      order_help(World.instance.get_project(p))
    }
    @layers << project
  end

  public
  def bind_deps
    World.log.debug "bind_deps for '#{name}'"
    deps_proj = {}
    sled = []
    @deps.each do |d|
      bind_from(d, deps_proj, sled)
    end
    deps_proj.each_value {|v|  @dep_projects << v}
  end

  def bind_from(dep_name, deps_proj, sled)
    World.log.debug "bind_from '#{dep_name}' for '#{name}'"
    proj = World.instance.get_project(dep_name)
    deps_proj[proj.name] = proj
    sled << proj.name
    proj.deps.each {|d|
      raise "Cyclic dependence found in #{dep_name} (#{sled.join(' ')})" if d == dep_name
      raise "Cyclic dependence found in #{dep_name} (#{sled.join(' ')})" if sled.length > World.instance.project_count * World.instance.project_count
      bind_from(d, deps_proj, sled)
    } unless proj.deps.empty?
  end

  def print_deps
    @dep_projects.join(' ') {|x| x.name}
  end

  def config_add_flags(flags)
    @current_config.flags.set(flags)
  end

end

class SolutionProject
  include PathContext
  attr_accessor :name, :projects, :path
  
  def initialize(name, maker)
    @name, @maker = name, maker
    @path = maker.path
    @project_names = []
    @projects = []
    World.instance.add_sln_project(self)
  end

  def add(name)
    @project_names << name
  end

  def bind_deps
    all_projects = {}
    @project_names.each do |p|
      proj = World.instance.get_project(p)
      all_projects[p] = proj
      proj.dep_projects.each {|p| all_projects[p.name] = p}
    end
    all_projects.each_value {|v| @projects << v}
  end

end


class Configuration
  include ActionStorage
  attr_accessor :name, :flags

  def initialize(name, flags)
    @name, @flags = name, flags
    @actions = []
  end

end

