# This file is managed via modulesync
# https://github.com/voxpupuli/modulesync
# https://github.com/voxpupuli/modulesync_config

# puppetlabs_spec_helper will set up coverage if the env variable is set.
# We want to do this if lib exists and it hasn't been explicitly set.
ENV['COVERAGE'] ||= 'yes' if Dir.exist?(File.expand_path('../../lib', __FILE__))

require 'voxpupuli/test/spec_helper'

if File.exist?(File.join(__dir__, 'default_module_facts.yml'))
  facts = YAML.safe_load(File.read(File.join(__dir__, 'default_module_facts.yml')))
  if facts
    facts.each do |name, value|
      add_custom_fact name.to_sym, value
    end
  end
end

# There's no real need to make this version dependent, but it helps find
# regressions in Puppet
#
# 1. Workaround for issue #16277 where default settings aren't initialised from
# a spec and so the libdir is never initialised (3.0.x)
# 2. Workaround for 2.7.20 that now only loads types for the current node
# environment (#13858) so Puppet[:modulepath] seems to get ignored
# 3. Workaround for 3.5 where context hasn't been configured yet,
# ticket https://tickets.puppetlabs.com/browse/MODULES-823
#
require 'pathname'
dir = Pathname.new(__FILE__).parent
ver = Gem::Version.new(Puppet.version.split('-').first)
if ver >= Gem::Version.new('2.7.20')
  puts 'augeasproviders: setting $LOAD_PATH to work around broken type autoloading'
  Puppet.initialize_settings
  $LOAD_PATH.unshift(
    dir,
    File.join(dir, 'fixtures/modules/augeasproviders_core/spec/lib'),
    File.join(dir, 'fixtures/modules/augeasproviders_core/lib'),
  )
  $LOAD_PATH.unshift(File.join(dir, '..', 'lib'))
end
