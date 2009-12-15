# Modules
module ComparableByValue
  def ==(other)
    Marshal.dump(self) == Marshal.dump(other)
  end

  def hash
    Marshal.dump(self).hash
  end
end

module DeepCopy
  def clone
    Marshal.load(Marshal.dump(self))
  end
end

# Classes
#   Flags class
class Flags
  include ComparableByValue
  include DeepCopy

  @@groups = []

  def initialize(flags = nil)
    @flags = {}
    if flags != nil
      flags.each do |f|
        if f.class === Enumerable
          f.each do |ff|
            @flags[ff] = nil
          end
        else
          @flags[f] = nil
        end
      end
    end
  end

  def Flags.define_group(*flags)
    @@groups << flags
  end

  def flags_hash
    @flags
  end

  def empty?
    @flags.keys.empty?  
  end

  def has?(flag)
    @flags.key?(flag)
  end

  def reset()
    @flags = {}
  end

  def set(*flags)
    if flags == nil
      reset()
    else
      flags.each do |f|
        @flags[f] = nil
      end
    end
  end

  def clear(*flags)
    flags.each do |f|
      @flags.delete(f)
    end
  end

  def include?(other)
    result = false
    if other.is_a? Flags
      other.flags_hash.keys.each do |f|
        result = true if @flags.include?(f)
      end
    else
      raise 'Unexpected include?'
    end
    result
  end

  def match?(other)
    return true if other == nil
    raise 'Unexpected match' unless other.is_a? Flags
    return true if empty?
    @flags.keys.each do |f|
      @@groups.each do |g|
        if g.include?(f)
          other.flags_hash.keys.each do |of|
            if g.include?(of) && of != f
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
          traverse("#{source_dir}/#{base_name}", mask, &block)
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

def normalize_path(path, backslash)
  if (backslash)
    path.gsub('/', '\\')
  else
    path.gsub('\\', '/')
  end
end


