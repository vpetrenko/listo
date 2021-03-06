$:[$:.length] = 'listo/'

require 'project'
require 'uuid'
require 'builder'

class VS2010Generator
  def initialize(project)
    @project = project
    @xml = nil
    @generated_files = {}
    @current_storage = nil
	@filters = {}
	@filter_props = {}
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

  def generate_file(file_path, sub_path)
    if File.extname(file_path) == '.cpp'
	  @xml.ClCompile :Include => file_path
	  @filters[file_path] = {'Filter' => "Source Files#{sub_path}", 'Type' => 'ClCompile'}
    end

	if File.extname(file_path) == '.h'
	  if !need_moc(file_path)
	    @xml.ClInclude :Include => file_path
		@filters[file_path] = {'Filter' => "Header Files#{sub_path}", 'Type' => 'ClInclude'}
	  else
	    @xml.CustomBuild :Include => file_path do
          @project.configurations.each_value do |config|
            storage = ConstStorage.new
            flags = config.flags
            flags.set(Maker::WIN32_X86)
            storage.path = @project.path_prefix
            storage.fill(@project.actions, flags)
            storage.fill(config.actions, flags)
            World.postprocess_storage(@project, config, storage)
			
			generated_file = "#{config.name}\\moc_#{File.basename(file_path, '.h')}.cpp"
			condition = "'$(Configuration)|$(Platform)'=='#{config.name}|Win32'"
			@xml.Message({:Condition => condition}, "MOC #{File.basename(file_path)}")
			@xml.Outputs({:Condition => condition}, "#{generated_file};%(Outputs)")
			@xml.AdditionalInputs({:Condition => condition}, "#{file_path};#{qt_moc};%(AdditionalInputs)")
			@xml.Command({:Condition => condition}, "#{qt_moc} #{storage.get_values(Maker::DEFINES, ' ', '-D')}" \
              " #{storage.get_decorated_paths(Maker::INCLUDE_DIRS, ' ', '-I', '', '"')}" \
              " #{file_path} -o #{config.name}\\moc_#{File.basename(file_path, '.h')}.cpp")
            @generated_files[config.name] = [] unless @generated_files.key?(config.name)
            @generated_files[config.name] << generated_file
			@filters[generated_file] = {'Filter' => 'Generated Files', 'Type' => 'ClCompile'}
          end
		end
		@filters[file_path] = {'Filter' => "Header Files#{sub_path}", 'Type' => 'CustomBuild'}
	  end
    end
  end

  def gen_files(xml, project, paths, sub_path = '')
    if paths == nil
      return
    end

    if paths.length == 1 && !paths.first[1].is_a?(String)
      gen_files(xml, project, paths.first[1], sub_path)
      return
    end

    paths.each do |k, v|
      if v.is_a? String
        generate_file(v, sub_path)
      end
    end

	paths.each do |k, v|
      if v.is_a? Hash
        gen_files(xml, project, v, sub_path + '\\' + k)
      end
    end
  end
  
  def generate_filters(project_file_name)
    File.open(project_file_name + ".filters", "w") do |file|
      xml = Builder::XmlMarkup.new(:indent => 2, :target => file)
      xml.instruct!
    
	  xml.Project :ToolsVersion => '4.0', :xmlns => 'http://schemas.microsoft.com/developer/msbuild/2003' do
	    xml.ItemGroup do
		  @filters.each_value {|val| @filter_props[val['Filter']] = {} unless @filter_props.has_key?(val['Filter'])}
		  @filter_props.each do |filter,props|
		    xml.Filter :Include => filter do
			  props.each do |key,val|
			    xml.__send__(key.to_sym, val)
			  end
			end
		  end
		end
	    xml.ItemGroup do
		  @filters.each do |file,desc|
		    xml.__send__(desc['Type'], :Include => file) do
			  xml.Filter desc['Filter']
			end
		  end		  
		end
	  end
	end
  end

  def generate_project(file_name)
    File.open(file_name, "w") do |file|
      xml = Builder::XmlMarkup.new(:indent => 2, :target => file)
      xml.instruct!
      @xml = xml
	  
	  xml.Project :DefaultTargets=> 'Build', :ToolsVersion => '4.0', :xmlns => 'http://schemas.microsoft.com/developer/msbuild/2003' do
	    xml.ItemGroup :Label => 'ProjectConfigurations' do
		  @project.configurations.each_value do |conf|
		    xml.ProjectConfiguration :Include => "#{conf.name}|Win32" do
		      xml.Configuration "#{conf.name}"
			  xml.Platform "Win32"
		    end
		  end
	    end
		xml.PropertyGroup :Label => 'Globals' do
		  xml.RootNamespace @project.name
		  xml.Keyword 'Win32Proj'
		  xml.ProjectGuid "{#{@project.guid}}"
		end
		xml.Import :Project => '$(VCTargetsPath)\Microsoft.Cpp.Default.props'
		@project.configurations.each_value do |config|
		  xml.PropertyGroup :Condition => "\'$(Configuration)|$(Platform)'=='#{config.name}|Win32'", :Label => 'Configuration' do
		    config_type = 'Application' if config.flags.has?(Maker::APP)
		    config_type = 'StaticLibrary' if config.flags.has?(Maker::LIB)
			xml.ConfigurationType config_type
			xml.CharacterSet 'Unicode'
		  end
		end
        xml.Import :Project => '$(VCTargetsPath)\Microsoft.Cpp.props'
		xml.ImportGroup :Label => 'ExtensionSettings'

		@project.configurations.each_value do |config|
		  xml.ImportGroup :Label => 'PropertySheets', :Condition => "'$(Configuration)|$(Platform)'=='#{config.name}|Win32'" do
			xml.Import :Project => '$(UserRootDir)\\Microsoft.Cpp.$(Platform).user.props',
				:Condition => "exists('$(UserRootDir)\\Microsoft.Cpp.$(Platform).user.props')",
				:Label => "LocalAppDataPlatform"
		  end
		end

		xml.PropertyGroup :Label => 'UserMacros'
		xml.PropertyGroup do
		  xml._ProjectFileVersion '10.0.30319.1'
		  @project.configurations.each_value do |conf|
            flags = conf.flags
            flags.set(Maker::WIN32_X86)

			storage = ConstStorage.new
            storage.path = @project.path_prefix
            storage.fill(@project.actions, flags)
            storage.fill(conf.actions, flags)
            World.postprocess_storage(@project, conf, storage)

			condition = "'$(Configuration)|$(Platform)'=='#{conf.name}|Win32'"
		
		    xml.OutDir({:Condition => condition}, storage.get_decorated_path(Maker::OUT_DIR))
            xml.IntDir({:Condition => condition}, storage.get_decorated_path(Maker::TEMP_DIR))
            xml.LinkIncremental({:Condition => condition}, true) if conf.flags.has?(Maker::APP)
            xml.GenerateManifest({:Condition => condition}, true) if conf.flags.has?(Maker::APP)
		  end
		end

		@project.configurations.each_value do |conf|
          flags = conf.flags
          flags.set(Maker::WIN32_X86)

		  conf_storage = ConstStorage.new
          conf_storage.path = @project.path_prefix
          conf_storage.fill(@project.actions, flags)
          conf_storage.fill(conf.actions, flags)
          World.postprocess_storage(@project, conf, conf_storage)
		  
		  #puts conf_storage.to_s

		  xml.ItemDefinitionGroup :Condition => "'$(Configuration)|$(Platform)'=='#{conf.name}|Win32'" do
		    xml.ClCompile do
              xml.RuntimeLibrary conf_storage.get_value(Maker::RUNTIME_LIB) == Maker::RELEASE_DLL ? 'MultiThreadedDLL' : 'MultiThreadedDebugDLL'
              xml.DebugInformationFormat 'ProgramDatabase'
              xml.ForceConformanceInForLoopScope true
              xml.Optimization 'Disabled'
              xml.AdditionalIncludeDirectories conf_storage.get_decorated_paths(Maker::INCLUDE_DIRS, ';') + ";%(AdditionalIncludeDirectories)"
              xml.AdditionalOptions conf_storage.get_value(Maker::CL_ADDIT_OPTIONS, ' ') + ' %(AdditionalOptions)'
              xml.PreprocessorDefinitions conf_storage.get_values(Maker::DEFINES, ';') + ';%(PreprocessorDefinitions)'
              xml.RuntimeTypeInfo true
              xml.StringPooling true
			  # Here we have to explicitly enable language extensions because of bugs in VC2010 STL
              xml.DisableLanguageExtensions false # conf_storage.get_value(Maker::DISABLE_LANGUAGE_EXTENSIONS)
              xml.PrecompiledHeader
              xml.MinimalRebuild true
              xml.ProgramDataBaseFileName '$(OutDir)$(ProjectName).pdb'
              xml.BasicRuntimeChecks 'EnableFastChecks'
              xml.WarningLevel 'Level4'
			  xml.TreatWChar_tAsBuiltInType conf_storage.get_values(Maker::TREAT_WCHAR, '')
			end
			xml.ResourceCompile do
			  xml.PreprocessorDefinitions conf_storage.get_values(Maker::DEFINES, ';') + ';%(PreprocessorDefinitions)'
			end

			if conf.flags.has?(Maker::APP)
			  xml.Link do
			    xml.AdditionalLibraryDirectories conf_storage.get_decorated_paths(Maker::LIB_DIRS, ';') + ';%(AdditionalLibraryDirectories)'
                xml.TargetMachine 'MachineX86'
                xml.AdditionalOptions conf_storage.get_values(Maker::LINK_ADDIT_OPTIONS, '') + ' %(AdditionalOptions)'
                xml.OutputFile conf_storage.get_decorated_path(Maker::OUT_FILE, conf_storage.get_decorated_path(Maker::OUT_DIR), '.exe')
                xml.AdditionalDependencies decorate_path(conf_storage.get_values(Maker::DEPS, ';', '', '.lib')) + ';%(AdditionalDependencies)'
                xml.GenerateDebugInformation true
			  end
			end

			if conf.flags.has?(Maker::LIB)
			  xml.Lib do
			    xml.IgnoreAllDefaultLibraries true
                xml.OutputFile conf_storage.get_decorated_path(Maker::OUT_FILE, conf_storage.get_decorated_path(Maker::OUT_DIR), '.lib')
			  end
			end
		  end
		end
		
		storage = ConstStorage.new
        storage.fill(@project.actions, @project.flags)
		@current_storage = storage

		if storage.has?(Maker::FILES_UI)
		  @filter_props['Form Files'] = {'UniqueIdentifier' => '{99349809-55BA-4b9d-BF79-8FDBB0286EB3}', 'Extensions' => 'ui'}
          xml.ItemGroup do
		    storage.get_array(Maker::FILES_UI).each do |ui|
              xml.CustomBuild :Include => ui do
                @project.configurations.each_value do |conf|
			      condition = "'$(Configuration)|$(Platform)'=='#{conf.name}|Win32'"
				  generated_file = "ui_#{File.basename(ui, '.ui')}.h"
				  xml.Message({:Condition => condition}, "UIC #{ui}")
				  xml.Outputs({:Condition => condition}, "ui_#{File.basename(ui, '.ui')}.h;%(Outputs)")
				  xml.AdditionalInputs({:Condition => condition}, "#{ui};#{qt_bin_path}\\uic.exe;%(AdditionalInputs)")
				  xml.Command({:Condition => condition}, "#{qt_bin_path}\\uic.exe #{ui} -o #{generated_file}")
                  @generated_files[conf.name] = [] unless @generated_files.key?(conf.name)
                  @generated_files[conf.name] << generated_file
				  @filters[generated_file] = {'Filter' => 'Generated Files', 'Type' => 'ClInclude'}
                end
				@filters[ui] = {'Filter' => 'Form Files', 'Type' => 'CustomBuild'}
              end
			end
		  end
        end

		xml.ItemGroup do
		  @filter_props['Header Files'] = {'UniqueIdentifier' => '{93995380-89BD-4b04-88EB-625FBE52EBFB}', 'Extensions' => 'h;hpp;hxx;hm;inl;inc;xsd'}
		  gen_files(xml, @project, prepare_files(storage.get_array(Maker::FILES_H))) if storage.has?(Maker::FILES_H)
          if !@generated_files.empty?
            @generated_files[@generated_files.keys[0]].each do |path|
			  if File.extname(path) == '.h'
                xml.ClInclude :Include => path do
				  xml.ExcludedFromBuild true
				end
              end
			end
		  end
        end
		
        if storage.has?(Maker::FILES_QRC)
		  @filter_props['Resource Files'] = {'UniqueIdentifier' => '{D9D6E242-F8AF-46E4-B9FD-80ECBC20BA3E}', 'Extensions' => 'qrc;*'}
		  xml.ItemGroup do
		    storage.get_array(Maker::FILES_QRC).each do |qrc|
			  xml.CustomBuild :Include =>qrc do
			    @project.configurations.each_value do |conf|
				  condition = "'$(Configuration)|$(Platform)'=='#{conf.name}|Win32'"
				  resource_files = ''
				  generated_file = "#{conf.name}\\qrc_#{File.basename(qrc, '.qrc')}.cpp"
                  storage.get_array(Maker::FILES_RESOURCES).each {|r| resource_files += r + ';'} if storage.has?(Maker::FILES_RESOURCES)
				  xml.Message({:Condition => condition}, "RCC #{qrc}")
				  xml.Outputs({:Condition => condition}, "#{conf.name}\\qrc_#{File.basename(qrc, '.qrc')}.cpp;%(Outputs)")
				  xml.AdditionalInputs({:Condition => condition}, "#{qrc};#{qt_bin_path}\\rcc.exe;#{resource_files};%(AdditionalInputs)")
				  xml.Command({:Condition => condition}, "#{qt_bin_path}\\rcc.exe -name #{@project.name} #{qrc} -o #{generated_file}")
				  @generated_files[conf.name] = [] unless @generated_files.key?(conf.name)
				  @generated_files[conf.name] << generated_file
				  @filters[generated_file] = {'Filter' => 'Generated Files', 'Type' => 'ClCompile'}
				end
				@filters[qrc] = {'Filter' => 'Resource Files', 'Type' => 'CustomBuild'}
			  end
			end
		  end
		end
		
		xml.ItemGroup do
		  @filter_props['Source Files'] = {'UniqueIdentifier' => '{4FC737F1-C7A5-4376-A066-2A32D752A2FF}', 'Extensions' => 'cpp;c;cc;cxx;def;odl;idl;hpj;bat;asm;asmx'}
		  gen_files(xml, @project, prepare_files(storage.get_array(Maker::FILES_CPP))) if storage.has?(Maker::FILES_CPP)
 
          if !@generated_files.empty?
		    @filter_props['Generated Files'] = {'UniqueIdentifier' => '{71ED8ED8-ACB9-4CE9-BBE1-E00B30144E11}', 'Extensions' => 'cpp;c;cxx;moc;h;def;odl;idl;res'}
            @generated_files.each_pair do |config, files|
              files.each do |path|
			    if File.extname(path) != '.h'
		          xml.ClCompile :Include => path do
				    xml.ExcludedFromBuild({:Condition => "'$(Configuration)|$(Platform)'!='#{config}|Win32'"}, true)
				  end
				end
              end
			end
		  end
		end
		
		unless @project.dep_projects.empty?
		  xml.ItemGroup do
            @project.dep_projects.each do |dp|
			  xml.ProjectReference :Include => @project.path_prefix + dp.path + '/' + dp.name + '.vcxproj' do
			    xml.Project "{#{dp.guid}}"
				xml.ReferenceOutputAssembly false
			  end
            end
		  end
		end
	
        xml.Import :Project => '$(VCTargetsPath)\Microsoft.Cpp.targets'
        xml.ImportGroup :Label=> 'ExtensionTargets'
	  end
	end
	
	generate_filters(file_name)

    puts "MSVC Project '#{@project.name}' generated at '#{file_name}'"
  end

end
