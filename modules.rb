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

module PathContext
  def initialize
    @path = ''
  end

  def path=(value)
    @path = value
  end

  def path
	@path.to_s
  end

  def path_prefix
	'../' * @path.to_s.count('/')
  end

  def decorated_path_prefix
    decorate_path(path_prefix)
  end
end

module ActionStorage
  attr_accessor :actions

  def do(action, params, flags)
    @actions = [] if @actions == nil
    @actions << ConstAction.new(action, params, flags, self)
  end

  def subs_params!(dict)
    @actions.each do |a|
      a.subs_params!(dict)
    end
  end

end