require 'modules'
# Classes
#   Flags class
class Flags
  include ComparableByValue
  include DeepCopy

  @@groups = []

  def initialize(*flags)
    @flags = {}
    flags.each do |f|
      if f.is_a? Flags
        f.flags_hash.each_key {|ff| add_flag(ff)}
      elsif f.is_a? Array
        f.each do |ff|
          if ff.is_a? Flags
            ff.flags_hash.each_key {|fff| add_flag(fff)}
          else
            add_flag(ff)
          end
        end
      else
        add_flag(f)
      end
    end
  end

  def add_flag(flag)
    raise "Could not add flag which is not symbol (#{flag}, #{flag.class}})." unless flag.is_a? Symbol
    @flags[flag] = nil
  end


  def Flags.define_group(*flags)
    flgs = []
    flags.each do |f|
      flgs << f.flags_hash.keys[0]
    end
    @@groups << flgs
  end

  def flags_hash
    @flags
  end

  def empty?
    @flags.keys.empty?  
  end

  def has?(flag)
    if flag.is_a? Flags
      @flags.key?(flag.flags_hash.keys[0])
    else
      @flags.key?(flag)
    end
  end

  def reset()
    @flags = {}
  end

  def set(*flags)
    if flags == nil
      reset()
    else
      flags.each do |f|
        if f.is_a? Flags
          f.flags_hash.each_key {|k| add_flag(k)}
        elsif f.is_a? Array
          f.each do |k|
            if k.is_a? Flags
              k.flags_hash.each_key {|kk| add_flag(kk)}
            else
              add_flag(k)
            end  
          end
        else
          add_flag(f)
        end
      end
    end
  end

  def add(flags)
    flags.flags_hash.each_key do |f|
      add_flag(f)
    end
  end

  def clear(*flags)
    flags.each do |f|
      @flags.delete(f)
    end
  end

  def include?(other)
    result = true
    if other.is_a? Flags
      other.flags_hash.each_key do |f|
        result = false unless @flags.include?(f)
      end
    else
      raise 'Unexpected include?'
    end
    result
  end

  def match?(other)
#    World.log.debug "Matching #{self} with #{other}."
    return true if other == nil
    raise 'Unexpected match' unless other.is_a? Flags
    return true if empty?
    @flags.keys.each do |f|
      @@groups.each do |g|
        if g.include?(f)
          other.flags_hash.keys.each do |of|
            if g.include?(of) && of != f
 #             World.log.debug "Result false."
              return false
            end
          end
        end
      end
    end
    true
  end

  def to_s
    "(#{@flags.keys.join(' ')})"
  end
end

#   FileSet class
class FileSet
  include ComparableByValue
  include DeepCopy

  attr_accessor :files

  def initialize(files = nil)
    if files == nil
      @files = []
    else
      @files = files
    end
  end

  def FileSet.all(path, mask, include = nil, exclude = nil)
    files = []
    adv_traverse(path, mask, include, exclude) do |f|
      files << f
    end
    FileSet.new(files)
  end

  def FileSet.cpp(path, include = nil, exclude = nil)
    all(path, /.+(\.cpp)$/, include, exclude)
  end

  def FileSet.h(path, include = nil, exclude = nil)
    all(path, /.+(\.h)$/, include, exclude)
  end

  def to_s
    @files.join("\n")
  end

end

# Functions
def traverse(path, mask, &block)
  source_dir = path
#File.dirname(path).sub /[\/\\]+$/, ''

  file_list = Dir[path + '/*']
  file_list.each do |entry|
    file_name = File.basename entry
    if FileTest.file? entry then
      if file_name.match mask
#        ext = file_name[/.+(\..+)/, 1]
        name = "#{source_dir}/#{file_name}"
#        $sizes[ext] += File.size(name)
#        puts "#{name} - #{File.size(name)}"
        block.call(name)
      end
    end
  end
  file_list.each do |entry|
    file_name = File.basename entry
    if FileTest.directory?(entry) then
      src = "#{source_dir}/#{file_name}"
      traverse(src, mask, &block) if file_name != '_svn'
    end
  end


end



def adv_traverse(path, mask, include, exclude, &block)
  include = '' if include == nil
  exclude = '' if exclude == nil
  include = [include] if include.class === String
  exclude = [exclude] if exclude.class === String
  exclude << '_svn' << '.svn'
  source_dir = path
#File.dirname(path).sub /[\/\\]+$/, ''

  file_list = Dir[Pathname.new(path) + '*']
  file_list.each do |entry|
    base_name = File.basename(entry)
    if FileTest.directory?(entry) then
      if include.include?(base_name) || include.include?('*')
        unless exclude.include?(base_name) || exclude.include?('*')
          adv_traverse("#{source_dir}/#{base_name}", mask, include, exclude, &block)
        end
      end
    end
    if FileTest.file?(entry) then
      if base_name.match mask
#        ext = file_name[/.+(\..+)/, 1]
        name = "#{source_dir}/#{base_name}"
#        $sizes[ext] += File.size(name)
#        puts "#{name} - #{File.size(name)}"
        block.call(name)
      end
    end
  end

end

def find_files(path, mask, &block)
  source_dir = path
  file_list = Dir[path + '/' + mask]
  file_list.each do |entry|
    file_name = File.basename entry
    if FileTest.file? entry then
      name = "#{source_dir}/#{file_name}"
      block.call(name)
    end
  end
end

def is_windows
  RUBY_PLATFORM.index('win32') != nil  
end

def is_unix
  !is_windows  
end

def find_qt_path()
  result = nil
  result = ENV['QTDIR'] if ENV.key?('QTDIR')
  if is_windows
    require 'dl'
    kernel32 = DL.dlopen("kernel32")
    get_logical_drives = kernel32['GetLogicalDrives', 'L']
    get_drive_type = kernel32['GetDriveTypeA','IS']
    r, rs = get_logical_drives.call()
    drives = []
    (0..26).each do |x|
      if (r & 1 << x) > 0
        drives << (?A + x).chr
      end
    end
    fixed_drives = []
    drives.each do |d|
      r, rs = get_drive_type.call(d + ':\\')
    # DRIVE_FIXED = 3
      if r == 3
        fixed_drives << d
      end
    end
    fixed_drives.each do |d|
      result = d + ':\\Qt' if File.exists?(d + ':\\Qt\bin')
    end
  else
  end
  puts "QT found in #{result}" if result != nil
  undecorate_path(result)
end

def qt_bin_path
  normalize_path(Pathname.new(World.get_config_variable(:qt_path)) + 'bin')
end

def qt_moc
  if is_windows
    normalize_path(Pathname.new(World.get_config_variable(:qt_path)) + 'bin' + 'moc.exe')
  elsif is_unix
    normalize_path(Pathname.new(World.get_config_variable(:qt_path)) + 'bin' + 'moc')
  else
    raise 'Unexpected platform.'
 end
end

def decorate_path(path)
  path.to_s.gsub(/\//, '\\')
end

def undecorate_path(path)
  path.to_s.gsub(/\\/, '/')
end

def param_subs!(string, name, value)
  string.gsub!('<%=' + name + '%>', value)
end

def normalize_path(path)
  if is_windows
    decorate_path(path.to_s)
  else
    path.to_s
  end
end




