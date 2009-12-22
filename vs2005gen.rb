$:[$:.length] = 'listo/'

require 'project'
require 'uuid'
require 'builder'


class VS2005Generator
  def initialize
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

  def gen_files(xml, project, paths, parent = '')
    if paths == nil
      return
    end

    if paths.length == 1 && !paths.first[1].is_a?(String)
      gen_files(xml, project, paths.first[1], parent)
      return
    end

    if parent != ''
      xml.Filter :Name => parent do
        gen_files(xml, project, paths, '')
      end
    else
    paths.each do |k, v|
      if v.is_a? String
        xml.File :RelativePath => decor_path(v) do
          if File.extname(v) == '.c'
            project.confs.each do |conf|
              xml.FileConfiguration :Name => "#{conf[1].name}|Win32" do
                xml.Tool :Name => 'VCCLCompilerTool', :CompileAs => '2'
              end
            end
          end
        end
      end
    end
    if parent == ''
      paths.each do |k, v|
        if v.is_a? Hash
          gen_files(xml, project, v, k)
        end
      end
    end
    end
  end


  def decor_path(path)
    path.gsub(/\//, '\\')
  end

  def gen_configurations(xml, project)
    project.confs.each do |configuration|
      config = configuration[1]
      config.flags.set(Maker::WIN32_X86)
      output_dir = config.template.format_single(Maker::OUT_DIR, config.flags)
      if output_dir.index('./') != 0
        output_dir = project.rev_path_prefix + output_dir
      end

      config_type = '1' if config.flags.has?(Maker::APP)
      config_type = '4' if config.flags.has?(Maker::LIB)

      xml.Configuration :Name => "#{config.name}|Win32",
          :OutputDirectory => decor_path(output_dir),
          :IntermediateDirectory => decor_path(config.template.format_single(Maker::TEMP_DIR, config.flags, project.rev_path_prefix)),
          :ConfigurationType => config_type,
          :InheritedPropertySheets => "",
          :CharacterSet => "1"  do

        xml.Tool :Name => "VCPreBuildEventTool"
        xml.Tool :Name => "VCCustomBuildTool"
        xml.Tool :Name => "VCXMLDataGeneratorTool"
        xml.Tool :Name => "VCWebServiceProxyGeneratorTool"
        xml.Tool :Name => "VCMIDLTool"
        xml.Tool :Name => "VCCLCompilerTool",
              :Optimization => "0",
              :AdditionalIncludeDirectories => decor_path(config.template.format(Maker::INCLUDE_DIRS, config.flags, ';', project.rev_path_prefix)),
              :PreprocessorDefinitions => config.template.format(Maker::DEFINES, config.flags, ';'),
              :StringPooling => "true",
              :MinimalRebuild => "true",
              :BasicRuntimeChecks => "3",
              :RuntimeLibrary => "3",
              :DisableLanguageExtensions => "false",
              :ForceConformanceInForLoopScope => "true",
              :RuntimeTypeInfo => "true",
              :UsePrecompiledHeader => "0",
              :ProgramDataBaseFileName => "$(OutDir)\\$(ProjectName).pdb",
              :WarningLevel => "4",
              :Detect64BitPortabilityProblems => "true",
              :DebugInformationFormat => "3"

        xml.Tool :Name => "VCManagedResourceCompilerTool"
        xml.Tool :Name => "VCResourceCompilerTool"
        xml.Tool :Name => "VCPreLinkEventTool"

        if config.flags.has?(Maker::APP)
          xml.Tool :Name => "VCLinkerTool",
				:AdditionalDependencies => decor_path(config.template.format(
                  Maker::DEPS, config.flags, ' ', '', '.lib')),
                :OutputFile => decor_path(config.template.format_single(Maker::OUT_FILE, config.flags, output_dir, '.exe')),
				:LinkIncremental => "2",
				:AdditionalLibraryDirectories => decor_path(config.template.format(
                  Maker::LIB_DIRS, config.flags, ';', project.rev_path_prefix)),
				:GenerateManifest => "true",
				:GenerateDebugInformation => "true",
				:SubSystem => "1",
				:TargetMachine => "1"
        elsif config.flags.has?(Maker::LIB)
          xml.Tool :Name => "VCLibrarianTool",
                   :OutputFile => decor_path(config.template.format_single(Maker::OUT_FILE, config.flags, output_dir, '.lib')),
                   :IgnoreAllDefaultLibraries => "true"
        end
        xml.Tool :Name => "VCALinkTool"
        xml.Tool :Name => "VCXDCMakeTool"
        xml.Tool :Name => "VCBscMakeTool"
        xml.Tool :Name => "VCFxCopTool"
        xml.Tool :Name => "VCPostBuildEventTool"
      end
    end
  end

  def generate_project(project, vcproj_file_name)
    File.open(vcproj_file_name, "w") do |file|
      xml = Builder::XmlMarkup.new(:indent => 2, :target => file)
      xml.instruct!
      xml.VisualStudioProject :ProjectType => 'Visual C++',
        :Version => "8,00", :Name => project.name, :ProjectGUID => "{#{project.guid}}",
        :RootNamespace => project.name, :Keyword => 'Win32Proj' do
        xml.Platforms do
          xml.Platform :Name => 'Win32'
        end
        xml.ToolFiles()
        xml.Configurations do
          gen_configurations(xml, project)
        end
        xml.References()
        xml.Files do
          xml.Filter :Name => 'Header Files', :Filter => 'h;hpp;hxx;hm;inl;inc;xsd', :UniqueIdentifier => '{93995380-89BD-4b04-88EB-625FBE52EBFB}' do
            gen_files(xml, project, prepare_files(project.h_sources))
          end
          xml.Filter :Name => 'Source Files', :Filter => 'cpp;c;cc;cxx;def;odl;idl;hpj;bat;asm;asmx', :UniqueIdentifier => '{4FC737F1-C7A5-4376-A066-2A32D752A2FF}' do
            gen_files(xml, project, prepare_files(project.cpp_sources))
          end
        end
      end
    end
    puts "MSVC Project '#{project.name}' generated at '#{vcproj_file_name}'"
  end
end


