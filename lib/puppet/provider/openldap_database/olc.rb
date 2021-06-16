require File.expand_path(File.join(File.dirname(__FILE__), %w[.. openldap]))
require 'base64'

Puppet::Type.
  type(:openldap_database).
  provide(:olc, parent: Puppet::Provider::Openldap) do

  # TODO: Use ruby bindings (can't find one that support IPC)

  defaultfor osfamily: [:debian, :freebsd, :redhat, :suse]

  mk_resource_methods

  def self.instances
    databases = slapcat('(|(olcDatabase=monitor)(olcDatabase={0}config)(&(objectClass=olcDatabaseConfig)(|(objectClass=olcBdbConfig)(objectClass=olcHdbConfig)(objectClass=olcMdbConfig)(objectClass=olcMonitorConfig)(objectClass=olcRelayConfig)(objectClass=olcLDAPConfig))))')

    databases.split("\n\n").map do |paragraph|
      suffix = nil
      relay = nil
      index = nil
      backend = nil
      directory = nil
      rootdn = nil
      rootpw = nil
      readonly = nil
      sizelimit = nil
      dbmaxsize = nil
      timelimit = nil
      updateref = nil
      dboptions = {}
      mirrormode = nil
      syncusesubentry = nil
      syncrepl = nil
      limits = []
      security = {}
      paragraph.gsub("\n ", '').split("\n").map do |line|
        case line
        when %r{^olcDatabase: }
          index, backend = line.match(%r{^olcDatabase: \{(\d+)\}(bdb|hdb|mdb|monitor|config|relay|ldap)$}).captures
        when %r{^olcDbDirectory: }
          directory = line.split(' ')[1]
        when %r{^olcRootDN: }
          rootdn = line.split(' ')[1]
        when %r{^olcRootPW:: }
          rootpw = Base64.decode64(line.split(' ')[1])
        when %r{^olcSuffix: }
          suffix = line.split(' ')[1]
        when %r{^olcRelay: }
          relay = line.split(' ')[1]
        when %r{^olcReadOnly: }i
          readonly = line.split(' ')[1]
        when %r{^olcSizeLimit: }i
          sizelimit = line.split(' ')[1]
        when %r{^olcDbMaxSize: }i
          dbmaxsize = line.split(' ')[1]
        when %r{^olcTimeLimit: }i
          timelimit = line.split(' ')[1]
        when %r{^olcUpdateref: }i
          updateref = line.split(' ')[1]
        when %r{^olcDb\S+: }i
          optname, optvalue = line.split(': ', 2)
          optname.downcase!
          case optname
          when 'olcdbconfig'
            dboptions['dbconfig'] = [] unless dboptions['dbconfig']
            optvalue = optvalue.match(%r{^\{\d+\}(.+)$}).captures[0] if optvalue =~ %r{^\{\d+\}.+$}
            dboptions['dbconfig'].push(optvalue)
          when 'olcdbnosync'
            dboptions['dbnosync'] = optvalue
          when 'olcdbpasesize'
            dboptions['dbpagesize'] = optvalue
          else
            ldifoptname = optname.match(%r{^olcDb(\S+)$}i).captures[0]
            if dboptions[ldifoptname] && !dboptions[ldifoptname].is_a?(Array)
              dboptions[ldifoptname] = [dboptions[ldifoptname]]
              dboptions[ldifoptname].push(optvalue)
            elsif dboptions[ldifoptname]
              dboptions[ldifoptname].push(optvalue)
            else
              dboptions[optname.match(%r{^olcDb(\S+)$}i).captures[0]] = optvalue
            end
          end
        when %r{^olcMirrorMode: }
          mirrormode = line.split(' ')[1] == 'TRUE' ? :true : :false
        when %r{^olcSyncUseSubentry: }
          syncusesubentry = line.split(' ', 2)[1]
        when %r{^olcSyncrepl: }
          syncrepl ||= []
          optvalue = line.split(' ', 2)[1]
          syncrepl.push(optvalue.match(%r{^(\{\d+\})?(.+)$}).captures[1])
        when %r{^olcLimits: }
          limit = line.match(%r{^olcLimits:\s+(\{\d+\})?(.+)$}).captures[1]
          limits << limit
        when %r{^olcSecurity: }
          line.split(': ')[1].split(' ').each do |variable|
            values = variable.split('=')
            security[values[0]] = values[1]
          end
        end
      end
      suffix = "cn=#{backend}" if backend.match(%r{monitor}i) && !suffix
      suffix = "cn=#{backend}" if backend.match(%r{config}i) && !suffix
      new(
        ensure: :present,
        name: suffix,
        suffix: suffix,
        relay: relay,
        index: index.to_i,
        backend: backend,
        directory: directory,
        rootdn: rootdn,
        rootpw: rootpw,
        readonly: readonly,
        sizelimit: sizelimit,
        timelimit: timelimit,
        dbmaxsize: dbmaxsize,
        updateref: updateref,
        dboptions: dboptions,
        mirrormode: mirrormode,
        syncusesubentry: syncusesubentry,
        syncrepl: syncrepl,
        limits: limits,
        security: security
      )
    end
  end

  def self.prefetch(resources)
    databases = instances
    resources.keys.each do |name|
      if (provider = databases.find { |database| database.name == name })
        resources[name].provider = provider
      end
    end
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def fetch_index
    slapcat("(&(objectClass=olc#{@property_hash[:backend].to_s.capitalize}Config)(olcSuffix=#{@property_hash[:suffix]}))").split("\n").map do |line|
      if line =~ %r{^olcDatabase: }
        @property_hash[:index] = line.match(%r{^olcDatabase: \{(\d+)\}#{@property_hash[:backend]}$}).captures[0].to_i
      end
    end
  end

  def destroy
    default_confdir = case Facter.value(:osfamily)
                      when 'Debian' then '/etc/ldap/slapd.d'
                      when 'RedHat' then '/etc/openldap/slapd.d'
                      when 'FreeBSD' then '/usr/local/etc/openldap/slapd.d'
                      end
    backend = @property_hash[:backend]

    fetch_index

    `service slapd stop`
    File.delete("#{default_confdir}/cn=config/olcDatabase={#{@property_hash[:index]}}#{backend}.ldif")
    slapcat("(objectClass=olc#{backend.to_s.capitalize}Config)").
      split("\n").
      select { |line| line =~ %r{^dn: } }.
      select { |dn| dn.match(%r{^dn: olcDatabase={(\d+)}#{backend},cn=config$}).captures[0].to_i > @property_hash[:index] }.
      each do |dn|
      index = dn[%r{\d+}].to_i
      old_filename = "#{default_confdir}/cn=config/olcDatabase={#{index}}#{backend}.ldif"
      new_filename = "#{default_confdir}/cn=config/olcDatabase={#{index - 1}}#{backend}.ldif"
      File.rename(old_filename, new_filename)
      text = File.read(new_filename)
      replace = text.gsub!("{#{index}}#{backend}", "{#{index - 1}}#{backend}")
      File.open(new_filename, 'w') { |file| file.puts replace }
    end
    `service slapd start`
    @property_hash.clear
  end

  def initdb
    t = Tempfile.new('openldap_database')
    t << "dn: #{resource[:suffix]}\n"
    t << "changetype: add\n"
    t << "objectClass: top\n"
    t << "objectClass: dcObject\n" if resource[:suffix].start_with?('dc=')
    t << "objectClass: organization\n"
    t << "dc: #{resource[:suffix].split(%r{,?dc=}).delete_if(&:empty?)[0]}\n" if resource[:suffix].start_with?('dc=')
    t << "o: #{resource[:suffix].split(%r{,?dc=}).delete_if(&:empty?).join('.')}\n" if resource[:suffix].start_with?('dc=')
    t << "\n"
    t << "dn: cn=admin,#{resource[:suffix]}\n"
    t << "objectClass: simpleSecurityObject\n" if resource[:rootpw]
    t << "objectClass: organizationalRole\n"
    t << "cn: admin\n"
    t << "description: LDAP administrator\n"
    t << "userPassword: #{resource[:rootpw]}\n" if resource[:rootpw]
    t.close
    Puppet.debug(IO.read(t.path))
    begin
      ldapadd(t.path)
    rescue StandardError => e
      raise Puppet::Error, "LDIF content:\n#{IO.read t.path}\nError message: #{e.message}"
    end
    t.delete
  end

  def create
    if resource[:rootpw] && resource[:rootpw] !~ %r{^\{(CRYPT|MD5|SMD5|SSHA|SHA(256|384|512)?)\}.+}
      require 'securerandom'
      salt = SecureRandom.random_bytes(4)
      @resource[:rootpw] = '{SSHA}' + Base64.encode64("#{Digest::SHA1.digest("#{resource[:rootpw]}#{salt}")}#{salt}").chomp
    end

    t = Tempfile.new('openldap_database')
    t << "dn: olcDatabase=#{resource[:backend]},cn=config\n"
    t << "changetype: add\n"
    t << "objectClass: olcDatabaseConfig\n"
    t << "objectClass: olc#{resource[:backend].to_s.capitalize}Config\n"
    t << "olcDatabase: #{resource[:backend]}\n"

    case resource[:backend].to_s
    when 'relay'
      t << "olcRelay: #{resource[:relay]}\n" unless resource[:relay].empty?
      t << "olcSuffix: #{resource[:suffix]}\n" if resource[:suffix]
    when 'monitor' # rubocop:disable Lint/EmptyWhen
      # WRITE HERE FOR MONITOR ONLY
    when 'ldap'
      # WRITE HERE FOR LDAP ONLY
      t << "olcSuffix: #{resource[:suffix]}\n" if resource[:suffix]
    else
      t << "olcDbDirectory: #{resource[:directory]}\n" if resource[:directory]
      t << "olcSuffix: #{resource[:suffix]}\n" if resource[:suffix]
      t << "olcDbIndex: objectClass eq\n" if !resource[:dboptions] || !resource[:dboptions]['index']
    end
    t << "olcRootDN: #{resource[:rootdn]}\n" if resource[:rootdn]
    t << "olcRootPW: #{resource[:rootpw]}\n" if resource[:rootpw]
    t << "olcReadOnly: #{resource[:readonly] == :true ? 'TRUE' : 'FALSE'}\n" if resource[:readonly]
    t << "olcSizeLimit: #{resource[:sizelimit]}\n" if resource[:sizelimit]
    t << "olcDbMaxSize: #{resource[:dbmaxsize]}\n" if resource[:dbmaxsize]
    t << "olcTimeLimit: #{resource[:timelimit]}\n" if resource[:timelimit]
    t << "olcUpdateref: #{resource[:updateref]}\n" if resource[:updateref]
    if resource[:dboptions]
      resource[:dboptions].each do |k, v|
        t << case k
             when 'dbnosync'
               "olcDbNosync: #{v}\n"
             when 'dbpagesize'
               "olcDbPagesize: #{v}\n"
             when 'dbconfig'
               v.map { |x| "olcDbConfig: #{x}" }.join("\n") + "\n"
             else
               if v.is_a?(Array)
                 v.map { |x| "olcDb#{k}: #{x}" }.join("\n") + "\n"
               else
                 "olcDb#{k}: #{v}\n"
               end
             end
      end
    end
    t << resource[:syncrepl].map { |x| "olcSyncrepl: #{x}" }.join("\n") + "\n" if resource[:syncrepl]
    t << "olcMirrorMode: #{resource[:mirrormode] == :true ? 'TRUE' : 'FALSE'}\n" if resource[:mirrormode]
    t << "olcSyncUseSubentry: #{resource[:syncusesubentry]}\n" if resource[:syncusesubentry]
    t << "#{resource[:limits].map { |x| "olcLimits: #{x}" }.join("\n")}\n" if resource[:limits] && !resource[:limits].empty?
    t << "#{resource[:security].map { |k, v| "olcSecurity: #{k}=#{v}" }.join("\n")}\n" if resource[:security] && !resource[:security].empty?
    t << "olcAccess: to * by dn.exact=gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth manage by * break\n"
    t << "olcAccess: to attrs=userPassword\n"
    t << "  by self write\n"
    t << "  by anonymous auth\n"
    t << "  by dn=\"cn=admin,#{resource[:suffix]}\" write\n"
    t << "  by * none\n"
    t << "olcAccess: to dn.base=\"\" by * read\n"
    t << "olcAccess: to *\n"
    t << "  by self write\n"
    t << "  by dn=\"cn=admin,#{resource[:suffix]}\" write\n"
    t << "  by * read\n"
    t.close
    Puppet.debug(IO.read(t.path))
    begin
      ldapmodify(t.path)
    rescue StandardError => e
      raise Puppet::Error, "LDIF content:\n#{IO.read t.path}\nError message: #{e.message}"
    end
    t.delete
    initdb if resource[:initdb] == :true
    @property_hash[:ensure] = :present
    slapcat("(&(objectClass=olc#{resource[:backend].to_s.capitalize}Config)(olcSuffix=#{resource[:suffix]}))").
      split("\n").map do |line|
      if line =~ %r{^olcDatabase: }
        @property_hash[:index] = line.match(%r{^olcDatabase: \{(\d+)\}#{resource[:backend]}$}).captures[0]
      end
    end
  end

  def initialize(value = {})
    super(value)
    @property_flush = {}
  end

  def directory=(value)
    @property_flush[:directory] = value
  end

  def rootdn=(value)
    @property_flush[:rootdn] = value
  end

  def rootpw=(value)
    @property_flush[:rootpw] = value
  end

  def suffix=(value)
    @property_flush[:suffix] = value
  end

  def relay=(value)
    @property_flush[:relay] = value
  end

  def readonly=(value)
    @property_flush[:readonly] = value
  end

  def sizelimit=(value)
    @property_flush[:sizelimit] = value
  end

  def timelimit=(value)
    @property_flush[:timelimit] = value
  end

  def dbmaxsize=(value)
    @property_flush[:dbmaxsize] = value
  end

  def updateref=(value)
    @property_flush[:updateref] = value
  end

  def dboptions=(value)
    @property_flush[:dboptions] = value
  end

  def mirrormode=(value)
    @property_flush[:mirrormode] = value
  end

  def syncusesubentry=(value)
    @property_flush[:syncusesubentry] = value
  end

  def syncrepl=(value)
    @property_flush[:syncrepl] = value
  end

  def limits=(value)
    @property_flush[:limits] = value
  end

  def security=(value)
    @property_flush[:security] = value
  end

  def flush
    unless @property_flush.empty?
      t = Tempfile.new('openldap_database')
      t << "dn: olcDatabase={#{@property_hash[:index]}}#{resource[:backend]},cn=config\n"
      t << "changetype: modify\n"
      t << "replace: olcDbDirectory\nolcDbDirectory: #{resource[:directory]}\n-\n" if @property_flush[:directory]
      t << "replace: olcRootDN\nolcRootDN: #{resource[:rootdn]}\n-\n" if @property_flush[:rootdn]
      t << "replace: olcRootPW\nolcRootPW: #{resource[:rootpw]}\n-\n" if @property_flush[:rootpw]
      t << "replace: olcSuffix\nolcSuffix: #{resource[:suffix]}\n-\n" if @property_flush[:suffix]
      t << "replace: olcRelay\nolcRelay: #{resource[:relay]}\n-\n" if @property_flush[:relay]
      t << "replace: olcReadOnly\nolcReadOnly: #{resource[:readonly] == :true ? 'TRUE' : 'FALSE'}\n-\n" if @property_flush[:readonly]
      t << "replace: olcSizeLimit\nolcSizeLimit: #{resource[:sizelimit]}\n-\n" if @property_flush[:sizelimit]
      t << "replace: olcTimeLimit\nolcTimeLimit: #{resource[:timelimit]}\n-\n" if @property_flush[:timelimit]
      t << "replace: olcDbMaxSize\nolcDbMaxSize: #{resource[:dbmaxsize]}\n-\n" if @property_flush[:dbmaxsize]
      if @property_flush[:dboptions]
        # rubocop:disable Metrics/BlockNesting
        if resource[:synctype].to_s == 'inclusive' && !@property_hash[:dboptions].empty?
          @property_hash[:dboptions].keys.each do |k|
            t << case k
                 when 'dbnosync'
                   "delete: olcDbNosync\n-\n"
                 when 'dbpagesize'
                   "delete: olcDbPagesize\n-\n"
                 when 'dbconfig'
                   "delete: olcDbConfig\n-\n"
                 else
                   "delete: olcDb#{k}\n-\n"
                 end
          end
        end
        @property_flush[:dboptions].each do |k, v|
          t << case k
               when 'dbnosync'
                 "replace: olcDbNosync\nolcDbNosync: #{v}\n-\n"
               when 'dbpagesize'
                 "replace: olcDbPagesize\nolcDbPagesize: #{v}\n-\n"
               when 'dbconfig'
                 "replace: olcDbConfig\n" + v.map { |x| "olcDbConfig: #{x}" }.join("\n") + "\n-\n"
               else
                 if v.is_a?(Array)
                   "replace: olcDb#{k}\n" + v.map { |x| "olcDb#{k}: #{x}" }.join("\n") + "\n-\n"
                 else
                   "replace: olcDb#{k}\nolcDb#{k}: #{v}\n-\n"
                 end
               end
        end
        # rubocop:enable Metrics/BlockNesting
      end
      t << "replace: olcSyncrepl\n#{resource[:syncrepl].map { |x| "olcSyncrepl: #{x}" }.join("\n")}\n-\n" if @property_flush[:syncrepl]
      t << "replace: olcUpdateref\nolcUpdateref: #{resource[:updateref]}\n-\n" if @property_flush[:updateref]
      t << "replace: olcMirrorMode\nolcMirrorMode: #{resource[:mirrormode] == :true ? 'TRUE' : 'FALSE'}\n-\n" if @property_flush[:mirrormode]
      t << "replace: olcSyncUseSubentry\nolcSyncUseSubentry: #{resource[:syncusesubentry]}\n-\n" if @property_flush[:syncusesubentry]
      t << "replace: olcLimits\n#{@property_flush[:limits].map { |x| "olcLimits: #{x}" }.join("\n")}\n-\n" if @property_flush[:limits]
      t << "replace: olcSecurity\n#{@property_flush[:security].map { |k, v| "olcSecurity: #{k}=#{v}" }.join("\n")}\n-\n" if @property_flush[:security]
      t.close
      Puppet.debug(IO.read(t.path))
      begin
        ldapmodify(t.path)
      rescue StandardError => e
        raise Puppet::Error, "LDIF content:\n#{IO.read t.path}\nError message: #{e.message}"
      end
      initdb if @property_flush[:directory]
    end
    @property_hash = resource.to_hash
  end
end
