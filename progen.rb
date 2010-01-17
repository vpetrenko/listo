$:[$:.length] = 'listo/'

require 'project'
require 'uuid'



class ProGenerator

#  class ProFile
#    def config(arg1, arg2, &block)
#      @file.puts 'CONFIG(debug, debug|release) {'
#      Config.new.instance_eval(&block)
#    end
#  end
#
#  class Config
#    def set(arg1, arg2)
#
#    end
#
#    def add(name, *args)
#
#    end
#  end

  def initialize
  end

  def out_configuration(file, storage, project, config, platform_name)
    file.puts "#{platform_name} {"
    file.puts "CONFIG(#{config.name.downcase}, debug|release) {"
    file.puts 'INCLUDEPATH = ' + storage.get_paths(Maker::INCLUDE_DIRS, ' ', '', '', '"')
    file.puts 'DESTDIR = ' + storage.get_path(Maker::OUT_DIR)
    file.puts 'DEFINES += ' + storage.get_values(Maker::DEFINES, ' ')
    file.puts 'LIBS += ' + storage.get_paths(Maker::LIB_DIRS, ' ', '-L', '', '"')
    file.puts 'LIBS += ' + storage.get_values(Maker::DEPS, ' ', '-l', '', '"')
    if platform_name == 'win32'
    file.puts "LIBS += -L#{project.path_prefix + 'lib/win32-x86-' + config.name.downcase}"
    elsif platform_name == 'unix'
      file.puts "LIBS += -L#{project.path_prefix + 'lib/unix-x86-' + config.name.downcase}"
    end
    file.puts '}'
    file.puts '}'
  end

  def generate_project(project, file_name)

#    ProFile.new(file).instance_eval do
#      config("aaa", "bb") do
#        set
#        add
#      end
#    end

    raise "Project #{project.name} has #{project.configurations.length} configurations but must have 2 for PRO generator" if project.configurations.length != 2

    debug_config = nil
    release_config = nil
    project.configurations.values.each do |c|
      debug_config = c if c.flags.has? Maker::DEBUG
      release_config = c if c.flags.has? Maker::RELEASE
    end

    raise "Project #{} must have one DEBUG and one RELEASE configuration" if debug_config == nil || release_config == nil

    File.open(file_name, "w") do |file|
      file.puts '# Generated by listo'
      file.puts 'QT -= core gui' if debug_config.flags.has? Maker::LIB
#      file.puts 'QT += core gui' if config.build_type == Template::BUILD_EXE
      file.puts 'TEMPLATE = lib' if debug_config.flags.has? Maker::LIB
      file.puts 'TEMPLATE = app' if debug_config.flags.has? Maker::APP
      file.puts 'CONFIG += staticlib' if debug_config.flags.has? Maker::LIB
      file.puts 'CONFIG += qt' if debug_config.flags.has? Maker::APP

      d_win_storage = ConstStorage.new
      flags = debug_config.flags
      flags.set(Maker::WIN32_X86)
      d_win_storage.path = project.path_prefix
      d_win_storage.fill(project.actions, flags)
      d_win_storage.fill(debug_config.actions, flags)
      World.postprocess_storage(project, debug_config, d_win_storage)

      r_win_storage = ConstStorage.new
      flags = release_config.flags
      flags.set(Maker::WIN32_X86)
      r_win_storage.path = project.path_prefix
      r_win_storage.fill(project.actions, flags)
      r_win_storage.fill(release_config.actions, flags)
      World.postprocess_storage(project, release_config, r_win_storage)

      d_unix_storage = ConstStorage.new
      flags = debug_config.flags
      flags.set(Maker::UNIX)
      d_unix_storage.path = project.path_prefix
      d_unix_storage.fill(project.actions, flags)
      d_unix_storage.fill(debug_config.actions, flags)
      World.postprocess_storage(project, debug_config, d_unix_storage)

      r_unix_storage = ConstStorage.new
      flags = release_config.flags
      flags.set(Maker::UNIX)
      r_unix_storage.path = project.path_prefix
      r_unix_storage.fill(project.actions, flags)
      r_unix_storage.fill(release_config.actions, flags)
      World.postprocess_storage(project, release_config, r_unix_storage)

      file.puts 'win32-msvc* {'
      file.puts "        GUID = #{project.guid}"
      file.puts '        QMAKE_CXXFLAGS_DEBUG += -Zc:wchar_t'
      file.puts '        QMAKE_CXXFLAGS_RELEASE += -Zc:wchar_t'
      file.puts '}'

      out_configuration(file, d_win_storage, project, debug_config, 'win32')
      out_configuration(file, r_win_storage, project, release_config, 'win32')
      out_configuration(file, d_unix_storage, project, debug_config, 'unix')
      out_configuration(file, r_unix_storage, project, release_config, 'unix')

      file.puts 'TARGET = ' + project.name

      cpp_files = ''

      d_unix_storage.get_array(Maker::FILES_CPP).each do |f|
        cpp_files += '    ' + f + " \\\n"
      end

      if cpp_files.length != 0
        cpp_files = cpp_files[0, cpp_files.length - 2]
        file.puts "SOURCES += \\\n" + cpp_files + "\n\n"
      end

      h_files = ''

      d_unix_storage.get_array(Maker::FILES_H).each { |f|
        h_files += '   ' + f + " \\\n"
      }
      if h_files.length != 0
        h_files = h_files[0, h_files.length - 2]
        file.puts "HEADERS += \\\n" + h_files + "\n\n"
      end

      if d_unix_storage.has?(Maker::FILES_QRC)
        qrc_files = ''
        d_unix_storage.get_array(Maker::FILES_QRC).each do |f|
          qrc_files += '    ' + f + " \\\n"
        end
        if qrc_files.length != 0
          qrc_files = qrc_files[0, qrc_files.length - 2]
          file.puts "RESOURCES += \\\n" + qrc_files + "\n\n"
        end
      end  

      if debug_config.flags.has? Maker::APP
        libs = ''
        project.dep_projects.each do |d|
          libs += '-l' + d.name + "\\\n"
        end
        if libs.length != 0
          libs = libs[0, libs.length - 2]
          file.puts "LIBS +=\\\n" + libs + "\n\n"
        end

        pre_libs = ''
        project.dep_projects.each do |d|
          pre_libs += project.path_prefix + 'lib/win32-x86-' + debug_config.name.downcase + '/lib' + d.name + ".a \\\n"
        end
        if pre_libs.length != 0
          pre_libs = pre_libs[0, pre_libs.length - 2]
          file.puts 'unix {'
          file.puts 'PRE_TARGETDEPS += ' + pre_libs
          file.puts '}'
        end
      end
    end
  end
end

