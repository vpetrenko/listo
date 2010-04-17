$:[$:.length] = 'listo/'

require 'project'
require 'uuid'
require 'builder'

##
# QT Mocs
#%QTDIR%/qmake/generators/makefiledeps.cpp
#"Q_"
#"QOM_"
#"OBJECT", "GADGET", "M_OBJECT"
##


class VS2005Generator
  def initialize(project, version)
    @project = project
    @xml = nil
    @generated_files = {}
    @current_storage = nil
    @version = version
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

  def need_moc(file_path)
#    puts "Checking file #{Pathname.new(@project.path) + file_path}"
    if @current_storage.has?(Maker::GENERATOR_TARGET) && @current_storage.get_array(Maker::GENERATOR_TARGET).find('Qt') != nil
      File.open(Pathname.new(@project.path) + file_path, "r") do |file|
        file.readlines.each do |line|
          return true if line.match(/(Q_|QOM_)(OBJECT|GADGET|M_OBJECT)/) != nil
        end
      end
    end
    false
  end

  def generate_file(file_path)
#				<FileConfiguration
#					Name="Debug|Win32">
#					<Tool
#						Name="VCCustomBuildTool"
#						AdditionalDependencies="GraphsView.h;g:/qt/4.5.3/bin\moc.exe"
#						CommandLine="g:/qt/4.5.3/bin\moc.exe  -DUNICODE -DWIN32 -DQT_LARGEFILE_SUPPORT -D_DEBUG -DQT_DLL -DQT_GUI_LIB -DQT_CORE_LIB -DQT_THREAD_SUPPORT -I&quot;g:\qt\4.5.3\include\QtCore&quot; -I&quot;g:\qt\4.5.3\include\QtGui&quot; -I&quot;g:\qt\4.5.3\include&quot; -I&quot;..\..\include&quot; -I&quot;..\..\deps\include&quot; -I&quot;g:\qt\4.5.3\include\ActiveQt&quot; -I&quot;debug&quot; -Ig:\qt\4.5.3\mkspecs\default -D_MSC_VER=1400 -DWIN32 GraphsView.h -o debug\moc_GraphsView.cpp"
#						Description="MOC GraphsView.h"
#						Outputs="debug\moc_GraphsView.cpp"
#						Path="g:\qt\4.5.3\bin"/>
#				</FileConfiguration>

    @xml.File :RelativePath => decorate_path(file_path) do
      if File.extname(file_path) == '.c'
        @project.confs.each do |conf|
          @xml.FileConfiguration :Name => "#{conf[1].name}|Win32" do
            @xml.Tool :Name => 'VCCLCompilerTool', :CompileAs => '2'
          end
        end
      end
      if File.extname(file_path) == '.h'
        if need_moc(file_path)
          @project.configurations.each_value do |config|
            storage = ConstStorage.new
            flags = config.flags
            flags.set(Maker::WIN32_X86)
            storage.path = @project.path_prefix
            storage.fill(@project.actions, flags)
            storage.fill(config.actions, flags)
            World.postprocess_storage(@project, config, storage)

            decor_path_pref = @project.decorated_path_prefix
            @xml.FileConfiguration :Name => "#{config.name}|Win32" do
              @xml.Tool :Name => 'VCCustomBuildTool', :AdditionalDependencies => "#{decorate_path(file_path)};#{qt_moc}",
                :CommandLine =>
                        "#{qt_moc} #{storage.get_values(Maker::DEFINES, ' ', '-D')}" \
              " #{storage.get_decorated_paths(Maker::INCLUDE_DIRS, ' ', '-I' '', '"')}" \
              " #{decorate_path(file_path)} -o #{config.name}\\moc_#{File.basename(file_path, '.h')}.cpp",
                :Description => "MOC #{File.basename(file_path)}",
                :Outputs => "#{config.name}\\moc_#{File.basename(file_path, ".h")}.cpp",
                :Path => qt_bin_path
              @generated_files[config.name] = [] unless @generated_files.key?(config.name)
              @generated_files[config.name] << "#{config.name}\\moc_#{File.basename(file_path, '.h')}.cpp"
            end
          end
        end
#				<FileConfiguration
#					Name="Debug|Win32">
#					<Tool
#						Name="VCCustomBuildTool"
#						AdditionalDependencies="GraphsView.h;g:/qt/4.5.3/bin\moc.exe"
#						CommandLine="g:/qt/4.5.3/bin\moc.exe  -DUNICODE -DWIN32 -DQT_LARGEFILE_SUPPORT -D_DEBUG -DQT_DLL -DQT_GUI_LIB -DQT_CORE_LIB -DQT_THREAD_SUPPORT -I&quot;g:\qt\4.5.3\include\QtCore&quot; -I&quot;g:\qt\4.5.3\include\QtGui&quot; -I&quot;g:\qt\4.5.3\include&quot; -I&quot;..\..\include&quot; -I&quot;..\..\deps\include&quot; -I&quot;g:\qt\4.5.3\include\ActiveQt&quot; -I&quot;debug&quot; -Ig:\qt\4.5.3\mkspecs\default -D_MSC_VER=1400 -DWIN32 GraphsView.h -o debug\moc_GraphsView.cpp"
#						Description="MOC GraphsView.h"
#						Outputs="debug\moc_GraphsView.cpp"
#						Path="g:\qt\4.5.3\bin"/>
#				</FileConfiguration>

      end
    end

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
        generate_file(v)
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

  def gen_configurations(xml, project)
    project.configurations.each_value do |config|
      flags = config.flags
      flags.set(Maker::WIN32_X86)
      storage = ConstStorage.new
      storage.path = project.path_prefix
      storage.fill(project.actions, flags)
      storage.fill(config.actions, flags)
#      puts "#{project.name} - #{config.name}"
      World.postprocess_storage(project, config, storage)
      output_dir = storage.get_decorated_path(Maker::OUT_DIR)

      config_type = '1' if config.flags.has?(Maker::APP)
      config_type = '4' if config.flags.has?(Maker::LIB)

      xml.Configuration :Name => "#{config.name}|Win32",
          :OutputDirectory => output_dir,
          :IntermediateDirectory => storage.get_decorated_path(Maker::TEMP_DIR),
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
              :AdditionalIncludeDirectories => storage.get_decorated_paths(Maker::INCLUDE_DIRS, ',', '', '', '"'),
              :PreprocessorDefinitions => storage.get_values(Maker::DEFINES, ';'),
              :StringPooling => "true",
              :MinimalRebuild => "true",
              :BasicRuntimeChecks => "3",
              :RuntimeLibrary => storage.get_value(Maker::RUNTIME_LIB),
              :DisableLanguageExtensions => storage.get_value(Maker::DISABLE_LANGUAGE_EXTENSIONS),
              :ForceConformanceInForLoopScope => "true",
              :RuntimeTypeInfo => "true",
              :UsePrecompiledHeader => "0",
              :ProgramDataBaseFileName => "$(OutDir)\\$(ProjectName).pdb",
              :WarningLevel => "4",
              :Detect64BitPortabilityProblems => "true",
              :DebugInformationFormat => "3",
              :AdditionalOptions => storage.get_value(Maker::CL_ADDIT_OPTIONS, '')

        xml.Tool :Name => "VCManagedResourceCompilerTool"
        xml.Tool :Name => "VCResourceCompilerTool", :PreprocessorDefinitions => storage.get_values(Maker::DEFINES, ',')
        xml.Tool :Name => "VCPreLinkEventTool"

        if config.flags.has?(Maker::APP)
#          @project.dep_projects.each {|x|
#            config.template.add(Const.new(Maker::LIB_DIRS, [x], nil, project))
#          }
          xml.Tool :Name => "VCLinkerTool",
				:AdditionalDependencies => decorate_path(storage.get_values(
                  Maker::DEPS, ' ', '', '.lib', '"')),
                :OutputFile => storage.get_decorated_path(Maker::OUT_FILE, output_dir, '.exe'),
				:LinkIncremental => "2",
				:AdditionalLibraryDirectories => storage.get_decorated_paths(
                  Maker::LIB_DIRS, ',', '', '', '"'),
				:GenerateManifest => "true",
				:GenerateDebugInformation => "true",
				:SubSystem => storage.get_value(Maker::SUBSYS, ''),
				:TargetMachine => "1",
                :AdditionalOptions => storage.get_values(Maker::LINK_ADDIT_OPTIONS, '')

        elsif config.flags.has?(Maker::LIB)
          xml.Tool :Name => "VCLibrarianTool",
                   :OutputFile => storage.get_decorated_path(Maker::OUT_FILE, output_dir, '.lib'),
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
      storage = ConstStorage.new
      storage.fill(project.actions, project.flags)
      @current_storage = storage
      xml = Builder::XmlMarkup.new(:indent => 2, :target => file)
      xml.instruct!
      @xml = xml
      xml.VisualStudioProject :ProjectType => 'Visual C++',
        :Version => "#{@version}", :Name => project.name, :ProjectGUID => "{#{project.guid}}",
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
            gen_files(xml, project, prepare_files(storage.get_array(Maker::FILES_H))) if storage.has?(Maker::FILES_H) 
          end
          xml.Filter :Name => 'Source Files', :Filter => 'cpp;c;cc;cxx;def;odl;idl;hpj;bat;asm;asmx', :UniqueIdentifier => '{4FC737F1-C7A5-4376-A066-2A32D752A2FF}' do
            gen_files(xml, project, prepare_files(storage.get_array(Maker::FILES_CPP))) if storage.has?(Maker::FILES_CPP)
          end
          if storage.has?(Maker::FILES_QRC)
            xml.Filter :Name => 'Resource Files',
                       :Filter => 'qrc;*',
                       :UniqueIdentifier => '{D9D6E242-F8AF-46E4-B9FD-80ECBC20BA3E}',
                       :ParseFiles => 'false' do
              storage.get_array(Maker::FILES_QRC).each do |qrc|
                xml.File :RelativePath => qrc do
                  @project.configurations.each_value do |conf|
                    xml.FileConfiguration :Name => "#{conf.name}|Win32" do
                      resource_files = ''
                      storage.get_array(Maker::FILES_RESOURCES).each {|r| resource_files += r + ';'} if storage.has?(Maker::FILES_RESOURCES)
                      @generated_files[conf.name] = [] unless @generated_files.key?(conf.name)
                      @generated_files[conf.name] << "#{conf.name}\\qrc_#{File.basename(qrc, '.qrc')}.cpp"
                      xml.Tool :Name => "VCCustomBuildTool",
                        :AdditionalDependencies => "#{qrc};#{qt_bin_path}\\rcc.exe;#{resource_files}",
                        :CommandLine => "#{qt_bin_path}\\rcc.exe -name #{@project.name} #{qrc} -o #{conf.name}\\qrc_#{File.basename(qrc, '.qrc')}.cpp",
                        :Description => "RCC #{qrc}",
                        :Outputs => "#{conf.name}\\qrc_#{File.basename(qrc, '.qrc')}.cpp",
                        :Path => qt_bin_path
                    end
                  end
                end
              end
            end
          end

          if storage.has?(Maker::FILES_UI)
            xml.Filter :Name => 'Form Files',
                       :Filter => 'ui',
                       :UniqueIdentifier => '{99349809-55BA-4b9d-BF79-8FDBB0286EB3}',
                       :ParseFiles => 'false' do
              storage.get_array(Maker::FILES_UI).each do |ui|
                xml.File :RelativePath => ui do
                  @project.configurations.each_value do |conf|
                    xml.FileConfiguration :Name => "#{conf.name}|Win32" do
                      ui_files = ''
                      storage.get_array(Maker::FILES_UI).each {|r| ui_files += r + ';'} if storage.has?(Maker::FILES_UI)
                      @generated_files[conf.name] = [] unless @generated_files.key?(conf.name)
                      @generated_files[conf.name] << "#{conf.name}\\ui_#{File.basename(ui, '.ui')}.h"
                      xml.Tool :Name => "VCCustomBuildTool",
                        :AdditionalDependencies => "#{ui};#{qt_bin_path}\\uic.exe",
                        :CommandLine => "#{qt_bin_path}\\uic.exe #{ui} -o ui_#{File.basename(ui, '.ui')}.h",
                        :Description => "UIC #{ui}",
                        :Outputs => "ui_#{File.basename(ui, '.ui')}.h",
                        :Path => qt_bin_path
                    end
                  end
                end
              end
            end
          end
#              <File
#                  RelativePath="OpsDemo5.qrc">
#                  <FileConfiguration
#                      Name="Debug|Win32">
#                      <Tool
#                          Name="VCCustomBuildTool"
#                          AdditionalDependencies="OpsDemo5.qrc;g:/qt/4.5.3/bin\rcc.exe;images\copy.png;images\cut.png;images\new.png;images\open.png;images\opensample.png;images\opsdemo5.png;images\parse.png;images\paste.png;images\redo.png;images\save.png;images\undo.png"
#                          CommandLine="g:/qt/4.5.3/bin\rcc.exe -name OpsDemo5 OpsDemo5.qrc -o debug\qrc_OpsDemo5.cpp"
#                          Description="RCC OpsDemo5.qrc"
#                          Outputs="debug\qrc_OpsDemo5.cpp"
#                          Path="g:\qt\4.5.3\bin"/>
#                  </FileConfiguration>

              if !@generated_files.empty?
                xml.Filter :Name => 'Generated Files', :Filter => "cpp;c;cxx;moc;h;def;odl;idl;res;", :UniqueIdentifier => '{71ED8ED8-ACB9-4CE9-BBE1-E00B30144E11}' do
                  @generated_files.each_pair do |config, files|
                    files.each do |path|
                      cfg = 'Debug' if config == 'Release'
                      cfg = 'Release' if config == 'Debug'
                      xml.File :RelativePath => path do
                        xml.FileConfiguration :Name => "#{cfg}|Win32", :ExcludedFromBuild => true
                      end
                    end
                  end
                end
              end
        end
       end
      end
    puts "MSVC Project '#{project.name}' generated at '#{vcproj_file_name}'"
  end
end


