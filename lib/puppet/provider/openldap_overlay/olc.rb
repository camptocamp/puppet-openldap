require File.expand_path(File.join(File.dirname(__FILE__), %w[.. openldap]))

# rubocop:disable Style/MethodName
# rubocop:disable Lint/RescueException
# rubocop:disable Lint/EmptyWhen
Puppet::Type.
  type(:openldap_overlay).
  provide(:olc, parent: Puppet::Provider::Openldap) do

  # TODO: Use ruby bindings (can't find one that support IPC)

  defaultfor osfamily: [:debian, :freebsd, :redhat, :suse]

  mk_resource_methods

  def self.instances
    slapcat('(olcOverlay=*)').split("\n\n").map do |paragraph|
      overlay = nil
      suffix = nil
      index = nil
      options = {}
      paragraph.gsub("\n ", '').split("\n").map do |line|
        case line
        when %r{^dn: }
          index, overlay, database = line.match(%r{^dn: olcOverlay=\{(\d+)\}([^,]+),olcDatabase=([^,]+),cn=config$}).captures
          suffix = getSuffix(database)
        when %r{^olcOverlay: }i
        when %r{^olc(\S+): }i
          opt_k, opt_v = line.split(': ', 2)
          opt_v = opt_v.split('}', 2)[1] if opt_v =~ %r{^\{\d+\}(.+)$}
          if options[opt_k] && !options[opt_k].is_a?(Array)
            options[opt_k] = [options[opt_k]]
            options[opt_k].push(opt_v)
          elsif options[opt_k]
            options[opt_k].push(opt_v)
          else
            options[opt_k] = opt_v
          end
        end
      end
      new(
        name: "#{overlay} on #{suffix}",
        ensure: :present,
        overlay: overlay,
        suffix: suffix,
        index: index.to_i,
        options: options.empty? ? nil : options
      )
    end
  end

  def self.prefetch(resources)
    overlays = instances
    resources.keys.each do |name|
      if (provider = overlays.find { |overlay| overlay.name == name })
        resources[name].provider = provider
      end
    end
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def create
    t = Tempfile.new('openldap_overlay')
    t << "dn: olcOverlay=#{resource[:overlay]},#{getDn(resource[:suffix])}\n"
    t << "changetype: add\n"
    t << "objectClass: olcConfig\n"
    t << "objectClass: olcOverlayConfig\n"
    case resource[:overlay]
    when 'memberof'
      t << "objectClass: olcMemberOf\n"
    when 'sock'
      t << "objectClass: olcOvSocketConfig\n"
    when 'ppolicy'
      t << "objectClass: olcPPolicyConfig\n"
    when 'dynlist'
      t << "objectClass: olcDynamicList\n"
    when 'auditlog'
      t << "objectClass: olcAuditLogConfig\n"
    when 'constraint'
      t << "objectClass: olcConstraintConfig\n"
    when 'pcache'
      t << "objectClass: olcPcacheConfig\n"
    when 'accesslog'
      t << "objectClass: olcAccessLogConfig\n"
    when 'syncprov'
      t << "objectClass: olcSyncProvConfig\n"
    when 'refint'
      t << "objectClass: olcRefintConfig\n"
    when 'unique'
      t << "objectClass: olcUniqueConfig\n"
    when 'rwm'
      t << "objectClass: olcRwmConfig\n"
    when 'smbk5pwd'
      t << "objectClass: olcSmbK5PwdConfig\n"
    when 'sssvlv'
      t << "objectClass: olcSssVlvConfig\n"
    end
    t << "olcOverlay: #{resource[:overlay]}\n"
    if resource[:options]
      resource[:options].each do |k, v|
        t << if v.is_a?(Array)
               v.map { |x| "#{k}: #{x}" }.join("\n") + "\n"
             else
               "#{k}: #{v}\n"
             end
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

  def getDn(suffix)
    if suffix == 'cn=config'
      if resource[:overlay].to_s == 'rwm'
        slapcat('(olcDatabase=relay)').split("\n").map do |line|
          return line.split(' ')[1] if line =~ %r{^dn: }
        end
      else
        'olcDatabase={0}config,cn=config'
      end
    else
      slapcat("(olcSuffix=#{suffix})").split("\n").map do |line|
        return line.split(' ')[1] if line =~ %r{^dn: }
      end
    end
  end

  def self.getSuffix(database)
    found = false
    slapcat("(olcDatabase=#{database})").split("\n").map do |line|
      if line =~ %r{^dn: olcDatabase=#{database.gsub('{', '\{').gsub('}', '\}')},}
        found = true
      end
      return 'cn=config' if database == '{0}config'
      return 'cn=config' if database =~ %r{\{\d+\}relay$}
      return line.split(' ')[1] if line =~ %r{^olcSuffix: } && found
    end
  end

  def initialize(value = {})
    super(value)
    @property_flush = {}
  end

  def options=(value)
    @property_flush[:options] = value
  end

  def flush
    unless @property_flush.empty?
      t = Tempfile.new('openldap_overlay')
      t << "dn: olcOverlay={#{@property_hash[:index]}}#{resource[:overlay]},#{getDn(resource[:suffix])}\n"
      t << "changetype: modify\n"
      if @property_flush[:options]
        if @property_hash[:options]
          # Remove all previously options remove in the should
          @property_hash[:options].reject { |key, _value| @property_flush[:options].member?(key) }.keys.each do |k|
            t << "delete: #{k}\n-\n"
          end
        end
        # Add current options
        @property_flush[:options].each do |k, v|
          action = if (@property_hash[:options] || {}).member?(k)
                     'replace'
                   else
                     'add'
                   end
          t << if v.is_a?(Array)
                 "#{action}: #{k}\n#{v.map { |x| "#{k}: #{x}" }.join("\n")}\n-\n"
               else
                 "#{action}: #{k}\n#{k}: #{v}\n-\n"
               end
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
    @property_has = resource.to_hash
  end

  def getPath(dn)
    dn.split(',').reverse.join('/') + '.ldif'
  end

  def destroy
    default_confdir = case Facter.value(:osfamily)
                      when 'Debian' then '/etc/ldap/slapd.d'
                      when 'RedHat' then '/etc/openldap/slapd.d'
                      when 'FreeBSD' then '/usr/local/etc/openldap/slapd.d'
                      end

    `service slapd stop`
    path = default_confdir + '/' + getPath("olcOverlay={#{@property_hash[:index]}}#{resource[:overlay]},#{getDn(resource[:suffix])}")
    File.delete(path)

    slapcat('(objectClass=olcOverlayConfig)', getDn(resource[:suffix])).
      split("\n").
      select { |line| line =~ %r{^dn: } }.
      select { |dn| dn.match(%r{^dn: olcOverlay=\{(\d+)\}(.+),#{Regexp.quote(getDn(resource[:suffix]))}$}).captures[0].to_i > @property_hash[:index] }.
      each do |dn|
      index, type = dn.match(%r{^dn: olcOverlay=\{(\d+)\}(.+),#{Regexp.quote(getDn(resource[:suffix]))}$}).captures
      index = index.to_i
      old_filename = "#{default_confdir}/#{getPath(dn.split(' ', 2)[1])}"
      new_filename = "#{default_confdir}/#{getPath("olcOverlay={#{index - 1}}#{type},#{getDn(@property_hash[:suffix])}")}"

      File.rename(old_filename, new_filename)
      text = File.read(new_filename)
      replace = text.gsub("{#{index}}#{type}", "{#{index - 1}}#{type}")
      File.open(new_filename, 'w') { |file| file.puts replace }
    end

    `service slapd start`
    @property_hash.clear
  end
end
