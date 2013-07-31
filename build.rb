#!/usr/bin/ruby

$:[$:.length] = 'listo/'

require 'world'


world = World.new
#World.log.level = Logger::DEBUG
if ARGV[0] == 'msvs2005'
world.explore
world.check
world.build_2005
elsif ARGV[0] == 'msvs2008'
world.explore
world.check
world.build_2008
if ARGV[1] == 'build'
world.build_all_sln
end
elsif ARGV[0] == 'msvs2010'
world.explore
world.check
world.build_2010
elsif ARGV[0] == 'pro'
world.explore
world.check
world.build_pro
else
world.explore
world.check
if is_windows()
  world.build_2005
else
  world.build_pro
end
end
#world.view_templates
#world.view_projects

