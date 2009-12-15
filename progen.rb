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

  def generate_project(project, file_name)
    config = project.confs.first[1]

#    ProFile.new(file).instance_eval do
#      config("aaa", "bb") do
#        set
#        add
#      end
#    end

    File.open(file_name, "w") do |file|
      file.puts '# Generated by listo'
      file.puts 'QT -= core gui' if config.flags.has? Maker::LIB
#      file.puts 'QT += core gui' if config.build_type == Template::BUILD_EXE
      file.puts 'TEMPLATE = lib' if config.flags.has? Maker::LIB
      file.puts 'TEMPLATE = app' if config.flags.has? Maker::APP
      file.puts 'CONFIG += staticlib' if config.flags.has? Maker::LIB
      file.puts 'CONFIG += qt' if config.flags.has? Maker::APP

      file.puts 'INCLUDEPATH += ' +
              config.template.format(Maker::INCLUDE_DIRS, config.flags, ' ', project.path_prefix, '', '')

      file.puts 'win32-msvc* {'
      file.puts "        GUID = #{project.guid}"
      file.puts '        QMAKE_CXXFLAGS_DEBUG += -Zc:wchar_t'
      file.puts '        QMAKE_CXXFLAGS_RELEASE += -Zc:wchar_t'
      file.puts '}'

      project.confs.each do |c|
        config = c[1]
        if (config.name.downcase == 'debug')
          file.puts 'CONFIG(debug, debug|release) {'
          file.puts 'win32:DESTDIR = ' + project.path_prefix + 'lib/win32-x86-' + config.name.downcase
          file.puts 'unix:DESTDIR = ' + project.path_prefix + 'lib/unix32-x86-' + config.name.downcase
          file.puts 'DEFINES += _DEBUG'
          file.puts '    }'
        end
        if (config.name.downcase == 'release')
          file.puts 'CONFIG(release, debug|release) {'
          file.puts 'win32:DESTDIR = ' + project.path_prefix + 'lib/win32-x86-' + config.name.downcase
          file.puts 'unix:DESTDIR = ' + project.path_prefix + 'lib/unix32-x86-' + config.name.downcase
          file.puts 'DEFINES += NDEBUG'
          file.puts '}'
        end
      end

      file.puts 'TARGET = ' + project.name

      cpp_files = ''

      project.cpp_sources.each do |f|
        cpp_files += '    ' + f + " \\\n"
      end

      if cpp_files.length != 0
        cpp_files = cpp_files[0, cpp_files.length - 2]
        file.puts "SOURCES += \\\n" + cpp_files + "\n\n"
      end

      h_files = ''

      project.h_sources.each { |f|
        h_files += '   ' + f + " \\\n"
      }
      if h_files.length != 0
        h_files = h_files[0, h_files.length - 2]
        file.puts "HEADERS += \\\n" + h_files + "\n\n"
      end

      if config.build_type == Template::BUILD_APP
        file.puts 'RESOURCES = OpsDemo5.qrc'

        project.confs.each do |c|
          config = c[1]
          file.puts "CONFIG(#{config.name.downcase}, debug|release) {"
          file.puts 'win32:LIBS += ' + project.path_prefix + 'lib/win32-x86-' + config.name.downcase + ' ' +
                  config.template.get_multiple(Template::LIB_DIRS, config.base_config,
                                               Template::WIN32_X86, ' ', project.path_prefix) + ' '
                  config.template.get_multiple(
                       Template::DEPS, config.base_config, Template::WIN32_X86, ' ', '', '')

          file.puts 'unix:LIBS += ' + project.path_prefix + 'lib/unix32-x86-' + config.name.downcase + ' ' +
                  config.template.get_multiple(Template::LIB_DIRS, config.base_config,
                                               Template::UNIX, ' ', project.path_prefix)

          file.puts 'unix {'
          file.puts '    LIBS += -lantlr -lantlr3c'
          file.puts '}'
          file.puts '}'
        end

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
          pre_libs += project.path_prefix + 'lib/win32-x86-' + config.name.downcase + '/lib' + d.name + ".a \\\n"
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

