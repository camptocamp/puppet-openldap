require File.expand_path(File.join(File.dirname(__FILE__), ['..', 'openldap']))
require 'tempfile'

Puppet::Type
  .type(:openldap_access)
  .provide(:olc, parent: Puppet::Provider::Openldap) do

  # TODO: Use ruby bindings (can't find one that support IPC)

  defaultfor osfamily: [:debian, :redhat]

  mk_resource_methods

  def self.instances
    # TODO: restict to bdb, hdb and globals
    i = []
    slapcat('(olcAccess=*)').split("\n\n").map do |paragraph|
      access = nil
      suffix = nil
      position = nil
      paragraph.gsub("\n ", '').split("\n").map do |line|
        case line
        when %r{^olcDatabase: }
          suffix = "cn=#{line.split(' ')[1].gsub(%r{\{-?\d+\}}, '')}"
        when %r{^olcSuffix: }
          suffix = line.split(' ')[1]
        when %r{^olcAccess: }
          position, what, bys = line.match(%r{^olcAccess:\s+\{(\d+)\}to\s+(\S+(?:\s+filter=\S+)?(?:\s+attrs=\S+)?(?:\s+val=\S+)?)(\s+by\s+.*)+$}).captures
          access = []
          bys.split(%r{(?= by .+)}).each do |b|
            access << b.lstrip
          end
          islast = if (position.to_i + 1) == getCountOfOlcAccess(suffix)
                     true
                   else
                     false
                   end
          i << new(
            name: "{#{position}}to #{what} #{access.join(' ')} on #{suffix}",
            ensure: :present,
            position: position,
            what: what,
            access: access,
            suffix: suffix,
            islast: islast,
          )
        end
      end
    end

    i
  end

  def self.prefetch(resources)
    accesses = instances
    resources.keys.each do |name|
      if provider = accesses.find do |access|
        if resources[name][:position]
          access.suffix == resources[name][:suffix] &&
          access.position == resources[name][:position].to_s
        else
          access.suffix == resources[name][:suffix] &&
          access.access.flatten == resources[name][:access].flatten &&
          access.what == resources[name][:what]
        end
      end
        resources[name].provider = provider
      end
      validate_islast(resources)
    end
  end

  def self.validate_islast(resources)
    islast = {}
    resources.keys.each do |name|
      if resources[name][:islast] == true
        if islast[resources[name][:suffix]].nil?
          islast[resources[name][:suffix]] = resources[name][:name]
        else
          raise Puppet::Error, "Multiple 'islast' found for suffix '#{resources[name][:suffix]}': #{resources[name][:name]} and #{islast[:suffix]}"
        end
      end
    end
  end

  def self.getDn(suffix)
    if suffix == 'cn=frontend'
      'olcDatabase={-1}frontend,cn=config'
    elsif suffix == 'cn=config'
      'olcDatabase={0}config,cn=config'
    elsif suffix == 'cn=monitor'
      slapcat('(olcDatabase=monitor)').split("\n").map do |line|
        if line =~ %r{^dn: }
          return line.split(' ')[1]
        end
      end
    else
      slapcat("(olcSuffix=#{suffix})").split("\n").map do |line|
        if line =~ %r{^dn: }
          return line.split(' ')[1]
        end
      end
    end
  end

  def getDn(*args)
    self.class.getDn(*args)
  end

  def exists?
    access = if resource[:position]
               {
                 suffix: resource[:suffix],
                 position: resource[:position].to_s,
               }
             else
               {
                 suffix: resource[:suffix],
                 access: resource[:access].flatten,
                 what: resource[:what],
               }
             end
    accesses = self.class.instances.map do |acc|
      acc_hash = acc.instance_variable_get(:@property_hash)
      acc_hash.select { |k, _v| access.key?(k) }
    end
    accesses.include?(access)
  end

  def create
    position = "{#{resource[:position]}}" if resource[:position]
    t = Tempfile.new('openldap_access')
    t << "dn: #{getDn(resource[:suffix])}\n"
    t << "add: olcAccess\n"
    t << if resource[:position]
           "olcAccess: {#{resource[:position]}}to #{resource[:what]}\n"
         else
           "olcAccess: to #{resource[:what]}\n"
         end
    resource[:access].flatten.each do |a|
      t << "  #{a}\n"
    end
    t.close
    Puppet.debug(IO.read(t.path))
    begin
      ldapmodify(t.path)
    rescue Exception => e
      raise Puppet::Error, "LDIF content:\n#{IO.read t.path}\nError message: #{e.message}"
    end
  end

  def destroy
    t = Tempfile.new('openldap_access')
    t << "dn: #{getDn(@property_hash[:suffix])}\n"
    t << "changetype: modify\n"
    t << "delete: olcAccess\n"
    t << "olcAccess: {#{@property_hash[:position]}}\n"
    if resource[:islast]
      t << "\n\n"
      t << "dn: #{getDn(resource[:suffix])}\n"
      t << "changetype: modify\n"
      t << "delete: olcAccess\n"
      (resource[:position].to_i + 1..getCountOfOlcAccess(resource[:suffix])).each do |n|
        t << "olcAccess: {#{n}}\n"
      end
    end
    t.close
    Puppet.debug(IO.read(t.path))
    begin
      ldapmodify(t.path)
    rescue Exception => e
      raise Puppet::Error, "LDIF content:\n#{IO.read t.path}\nError message: #{e.message}"
    end
  end

  def initialize(value = {})
    super(value)
    @property_flush = {}
  end

  def what=(value)
    @property_flush[:what] = value
  end

  def suffix=(value)
    @property_flush[:suffix] = value
  end

  def position=(value)
    @property_flush[:position] = value
  end

  def access=(value)
    @property_flush[:access] = value.flatten
  end

  def islast=(value)
    @property_flush[:islast] = value
  end

  def self.getCountOfOlcAccess(suffix)
    countOfElement = 0
    slapcat('(olcAccess=*)', getDn(suffix).to_s).split("\n\n").map do |paragraph|
      paragraph.gsub("\n ", '').split("\n").map do |line|
        case line
        when %r{^olcAccess: }
          countOfElement += 1
        end
      end
    end
    countOfElement
  end

  def getCurrentOlcAccess(suffix)
    i = []
    slapcat('(olcAccess=*)', getDn(suffix).to_s).split("\n\n").map do |paragraph|
      paragraph.gsub("\n ", '').split("\n").map do |line|
        case line
        when %r{^olcAccess: }
          position, content = line.match(%r{^olcAccess:\s+\{(\d+)\}(.*)$}).captures
          i << {
            position: position,
            content: content,
          }
        end
      end
    end
    i
  end

  def flush
    unless @property_flush.empty?
      current_olcAccess = getCurrentOlcAccess(resource[:suffix])
      t = Tempfile.new('openldap_access')
      t << "dn: #{getDn(resource[:suffix])}\n"
      t << "changetype: modify\n"
      t << "replace: olcAccess\n"
      position = if resource[:position]
                   resource[:position]
                 else
                   @property_hash[:position]
                 end
      current_olcAccess.each do |olcAccess|
        if olcAccess[:position].to_i == position.to_i
          t << "olcAccess: {#{position}}to #{resource[:what]}\n"
          resource[:access].flatten.each do |a|
            t << "  #{a}\n"
          end
        else
          t << "olcAccess: {#{olcAccess[:position]}}#{olcAccess[:content]}\n"
        end
      end
      countOfElement = self.class.getCountOfOlcAccess(resource[:suffix])
      if resource[:islast] && countOfElement > (position.to_i + 1)
        t << "-\n"
        t << "delete: olcAccess\n"
        (position.to_i + 1..countOfElement - 1).each do |n|
          t << "olcAccess: {#{n}}\n"
        end
      end
      t.close
      Puppet.debug(IO.read(t.path))
      begin
        ldapmodify(t.path)
      rescue Exception => e
        raise Puppet::Error, "LDIF content:\n#{IO.read t.path}\nError message: #{e.message}"
      end
    end
    @property_hash = resource.to_hash
  end
end
