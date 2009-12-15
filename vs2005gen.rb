$:[$:.length] = 'listo/'

require 'project'
require 'uuid'
require 'xmlbuilder'


class VS2005Generator
  def initialize
    @conf_template = Templater.new('listo/templates/vcproj/conf.xml')
    @library_tool_template = Templater.new('listo/templates/vcproj/library-tool.xml')
    @linker_tool_template = Templater.new('listo/templates/vcproj/linker-tool.xml')
  end
  def prepare_files(sources)
    paths = {}
    sources.each do |f|
      components = f.split('/')
      i = 0
      np = paths
      while i < components.length - 1
        if np[components[i]] == nil
          np[components[i]] = {}
        end
        np = np[components[i]]
        i += 1
      end
      np[components[-1]] = f
    end
    paths
  end

  def gen_files(paths, first = '', parent = '')
    result = ''
    paths.each do |k, v|
      if v.is_a? String
        if first != '' && result == ''
          result += "<Filter Name=\"#{parent}\">\n"
        end
        result += "<File RelativePath=\"#{normalize_path(v, true)}\"></File>\n"
      end
    end
    if first != ''
      result += "</Filter>\n"
    end
    paths.each do |k, v|
      if v.is_a? Hash
        result += gen_files(v, result, k)
      end
    end
    result
  end

  def gen_confs(project)
    confs = ''
    project.confs.each do |configuration|
      @conf_template.reset
      config = configuration[1]
      config.flags.set(Maker::WIN32_X86)
      @conf_template.subs('ConfName', config.name)
      output_dir = config.template.format_single(Maker::OUT_DIR, config.flags)
      if output_dir.index('./') != 0
        output_dir = project.rev_path_prefix + output_dir 
      end
      @conf_template.subs_path('OutputDirectory', output_dir)
      @conf_template.subs_path('IntermediateDirectory',
                               config.template.format_single(Maker::TEMP_DIR, config.flags, project.rev_path_prefix))
      @conf_template.subs_path('AdditionalIncludeDirectories',
        config.template.format(Maker::INCLUDE_DIRS, config.flags, ';', project.rev_path_prefix))

      @conf_template.subs('PreprocessorDefinitions',
                          config.template.format(Maker::DEFINES, config.flags, ';'))

      if config.flags.has?(Maker::APP)
        # Linker
        @conf_template.subs('ConfigurationType', '1')
        @linker_tool_template.reset
        @linker_tool_template.subs_path('OutputFile', config.template.format_single(Maker::OUT_FILE, config.flags, output_dir, '.exe'))
        @linker_tool_template.subs_path('AdditionalDependencies', config.template.format(
                Maker::DEPS, config.flags, ' ', '', '.lib'))
        @linker_tool_template.subs_path('AdditionalLibraryDirectories', config.template.format(
                Maker::LIB_DIRS, config.flags, ';', project.rev_path_prefix))
        @conf_template.subs('CustomTools', @linker_tool_template.result)
      elsif config.flags.has?(Maker::LIB)
        # Library
        @conf_template.subs('ConfigurationType', '4')
        @library_tool_template.reset
        @library_tool_template.subs_path('OutputFile', config.template.format_single(Maker::OUT_FILE, config.flags, output_dir, '.lib'))
        @conf_template.subs('CustomTools', @library_tool_template.result)
      end
      confs += @conf_template.result
    end
    confs
  end

  def generate_project(project, vcproj_file_name)
    cpp_files_xml = gen_files(prepare_files(project.cpp_sources))
    h_files_xml = gen_files(prepare_files(project.h_sources))
    confs_xml = gen_confs(project)
    xml.clear()
    xml.VisualStudioProject :ProjectType => 'Visual C++',
      :Version => "8,00", :Name => project.name, :ProjectGUID => "{#{project.guid}}",
	  :RootNamespace => project.name, :Keyword => 'Win32Proj' do
      Platforms do
        Platform :Name => 'Win32'
      end
      ToolFiles()
      Configurations do
        clear_write(confs_xml)
      end
      References()
      Files do
        Filter :Name => 'Source Files', :Filter => 'cpp;c;cc;cxx;def;odl;idl;hpj;bat;asm;asmx', :UniqueIdentifier => '{4FC737F1-C7A5-4376-A066-2A32D752A2FF}' do
          clear_write(cpp_files_xml)
        end  
        Filter :Name => 'Header Files', :Filter => 'h;hpp;hxx;hm;inl;inc;xsd', :UniqueIdentifier => '{93995380-89BD-4b04-88EB-625FBE52EBFB}' do
          clear_write(h_files_xml)
        end
      end
    end
    File.open(vcproj_file_name, "w") do |file|
      file.puts xml
    end
    puts "MSVC Project '#{project.name}' generated at '#{vcproj_file_name}'"
  end
end

class Templater
  attr_reader :result

  def initialize(template)
    @template = IO.read(template)
    @result = @template.dup
  end

  def reset
    @result = @template.dup
  end

  def subs(name, value)
    @result.gsub!('<%=' + name + '%>', value)
    self
  end

  def subs_path(name, value)
    @result.gsub!('<%=' + name + '%>', value.gsub("/", "\\"))
    self
  end
end


