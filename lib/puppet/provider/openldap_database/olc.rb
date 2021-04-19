require File.expand_path(File.join(File.dirname(__FILE__), %w[.. openldap]))
require 'base64'

Puppet::Type.
  type(:openldap_database).
  provide(:olc, :parent => Puppet::Provider::Openldap) do

  # TODO: Use ruby bindings (can't find one that support IPC)

  defaultfor :osfamily => [:debian, :freebsd, :redhat, :suse]

  mk_resource_methods

  def self.instances
    databases = slapcat("(|(olcDatabase=monitor)(olcDatabase={0}config)(&(objectClass=olcDatabaseConfig)(|(objectClass=olcBdbConfig)(objectClass=olcHdbConfig)(objectClass=olcMdbConfig)(objectClass=olcMonitorConfig)(objectClass=olcRelayConfig)(objectClass=olcLDAPConfig))))")

    databases.split("\n\n").collect do |paragraph|
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
      paragraph.gsub("\n ", "").split("\n").collect do |line|
        case line
        when /^olcDatabase: /
          index, backend = line.match(/^olcDatabase: \{(\d+)\}(bdb|hdb|mdb|monitor|config|relay|ldap)$/).captures
        when /^olcDbDirectory: /
          directory = line.split(' ')[1]
        when /^olcRootDN: /
          rootdn = line.split(' ')[1]
        when /^olcRootPW:: /
          rootpw = Base64.decode64(line.split(' ')[1])
        when /^olcSuffix: /
          suffix = line.split(' ')[1]
        when /^olcRelay: /
          relay = line.split(' ')[1]
        when /^olcReadOnly: /i
          readonly = line.split(' ')[1]
        when /^olcSizeLimit: /i
          sizelimit = line.split(' ')[1]
        when /^olcDbMaxSize: /i
          dbmaxsize = line.split(' ')[1]
        when /^olcTimeLimit: /i
          timelimit = line.split(' ')[1]
        when /^olcUpdateref: /i
          updateref = line.split(' ')[1]
        when /^olcDb\S+: /i
          optname, optvalue = line.split(': ',2)
          optname.downcase!
          case optname
          when 'olcdbconfig'
            dboptions['dbconfig'] = [] if !dboptions['dbconfig']
            optvalue = optvalue.match(/^\{\d+\}(.+)$/).captures[0] if optvalue =~ /^\{\d+\}.+$/
            dboptions['dbconfig'].push(optvalue)
          when 'olcdbnosync'
            dboptions['dbnosync'] = optvalue
          when 'olcdbpasesize'
            dboptions['dbpagesize'] = optvalue
          else
            ldifoptname = optname.match(/^olcDb(\S+)$/i).captures[0]
            if dboptions[ldifoptname] and !dboptions[ldifoptname].is_a?(Array)
              dboptions[ldifoptname] = [dboptions[ldifoptname]]
              dboptions[ldifoptname].push(optvalue)
            elsif dboptions[ldifoptname]
              dboptions[ldifoptname].push(optvalue)
            else
              dboptions[optname.match(/^olcDb(\S+)$/i).captures[0]] = optvalue
            end
          end
        when /^olcMirrorMode: /
          mirrormode = line.split(' ')[1] == 'TRUE' ? :true : :false
        when /^olcSyncUseSubentry: /
          syncusesubentry = line.split(' ', 2)[1]
        when /^olcSyncrepl: /
          syncrepl ||= []
          optvalue = line.split(' ',2)[1]
          syncrepl.push(optvalue.match(/^(\{\d+\})?(.+)$/).captures[1])
        when /^olcLimits: /
          limit = line.match(/^olcLimits:\s+(\{\d+\})?(.+)$/).captures[1]
          limits << limit
        when /^olcSecurity: /
          line.split(': ')[1].split(' ').each do |variable|
            values = variable.split('=')
            security[values[0]] = values[1]
          end
        end
      end
      if backend.match(/monitor/i) and !suffix
        suffix = "cn=#{backend}"
      end
      if backend.match(/config/i) and !suffix
        suffix = "cn=#{backend}"
      end
      new(
        :ensure          => :present,
        :name            => suffix,
        :suffix          => suffix,
        :relay           => relay,
        :index           => index.to_i,
        :backend         => backend,
        :directory       => directory,
        :rootdn          => rootdn,
        :rootpw          => rootpw,
        :readonly        => readonly,
        :sizelimit       => sizelimit,
        :timelimit       => timelimit,
        :dbmaxsize       => dbmaxsize,
        :updateref       => updateref,
        :dboptions       => dboptions,
        :mirrormode      => mirrormode,
        :syncusesubentry => syncusesubentry,
        :syncrepl        => syncrepl,
        :limits          => limits,
        :security        => security
      )
    end
  end

  def self.prefetch(resources)
    databases = instances
    resources.keys.each do |name|
      if provider = databases.find{ |database| database.name == name }
        resources[name].provider = provider
      end
    end
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def fetch_index
    slapcat("(&(objectClass=olc#{@property_hash[:backend].to_s.capitalize}Config)(olcSuffix=#{@property_hash[:suffix]}))").split("\n").collect do |line|
      if line =~ /^olcDatabase: /
        @property_hash[:index] = line.match(/^olcDatabase: \{(\d+)\}#{@property_hash[:backend]}$/).captures[0].to_i
      end
    end
  end

  def destroy
    default_confdir = case Facter.value(:osfamily)
                      when 'Debian' then '/etc/ldap/slapd.d'
                      when 'RedHat' then '/etc/openldap/slapd.d'
                      when 'FreeBSD' then '/usr/local/etc/openldap/slapd.d'
                      else nil
                      end
    backend = @property_hash[:backend]

    fetch_index

    `service slapd stop`
    File.delete("#{default_confdir}/cn=config/olcDatabase={#{@property_hash[:index]}}#{backend}.ldif")
    slapcat("(objectClass=olc#{backend.to_s.capitalize}Config)").
      split("\n").
      select { |line| line =~ /^dn: / }.
      select { |dn| dn.match(/^dn: olcDatabase={(\d+)}#{backend},cn=config$/).captures[0].to_i > @property_hash[:index] }.
      each do |dn|
        index = dn[/\d+/].to_i
        old_filename = "#{default_confdir}/cn=config/olcDatabase={#{index}}#{backend}.ldif"
        new_filename = "#{default_confdir}/cn=config/olcDatabase={#{index - 1}}#{backend}.ldif"
        File.rename(old_filename, new_filename)
        text = File.read(new_filename)
        replace = text.gsub!("{#{index}}#{backend}", "{#{index - 1}}#{backend}")
        File.open(new_filename, "w") { |file| file.puts replace }
    end
    `service slapd start`
    @property_hash.clear
  end

  def initdb
    t = Tempfile.new('openldap_database')
    t << "dn: #{resource[:suffix]}\n"
    t << "changetype: add\n"
    t << "objectClass: top\n"
    t << "objectClass: dcObject\n" if resource[:suffix].start_with?("dc=")
    t << "objectClass: organization\n"
    t << "dc: #{resource[:suffix].split(/,?dc=/).delete_if { |c| c.empty? }[0]}\n" if resource[:suffix].start_with?("dc=")
    t << "o: #{resource[:organization]}\n" if resource[:organization]
    if resource[:rootdn]
      t << "\n"
      t << "dn: #{resource[:rootdn]}\n"
      t << "objectClass: simpleSecurityObject\n" if resource[:rootpw]
      t << "objectClass: organizationalRole\n"
      t << "cn: #{resource[:rootdn].split(/,|=/)[1]}\n"
      t << "description: LDAP administrator\n"
      t << "userPassword: #{resource[:rootpw]}\n" if resource[:rootpw]
    end
    t.close
    Puppet.debug(IO.read t.path)
    begin
      ldapadd(t.path)
    rescue Exception => e
      raise Puppet::Error, "LDIF content:\n#{IO.read t.path}\nError message: #{e.message}"
    end
    t.delete
  end

  def create
    if resource[:rootpw] && resource[:rootpw] !~ /^\{(CRYPT|MD5|SMD5|SSHA|SHA(256|384|512)?)\}.+/
      require 'securerandom'
      salt = SecureRandom.random_bytes(4)
      @resource[:rootpw] = "{SSHA}" + Base64.encode64("#{Digest::SHA1.digest("#{resource[:rootpw]}#{salt}")}#{salt}").chomp
    end

    t = Tempfile.new('openldap_database')
    t << "dn: olcDatabase=#{resource[:backend]},cn=config\n"
    t << "changetype: add\n"
    t << "objectClass: olcDatabaseConfig\n"
    t << "objectClass: olc#{resource[:backend].to_s.capitalize}Config\n"
    t << "olcDatabase: #{resource[:backend]}\n"

    case "#{resource[:backend]}"
    when "relay"
      t << "olcRelay: #{resource[:relay]}\n" if !resource[:relay].empty?
      t << "olcSuffix: #{resource[:suffix]}\n" if resource[:suffix]
    when "monitor"
      # WRITE HERE FOR MONITOR ONLY
    when "ldap"
      # WRITE HERE FOR LDAP ONLY
      t << "olcSuffix: #{resource[:suffix]}\n" if resource[:suffix]
    else
      t << "olcDbDirectory: #{resource[:directory]}\n" if resource[:directory]
      t << "olcSuffix: #{resource[:suffix]}\n" if resource[:suffix]
      t << "olcDbIndex: objectClass eq\n" if !resource[:dboptions] or !resource[:dboptions]['index']
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
        case k
        when 'dbnosync'
          t << "olcDbNosync: #{v}\n"
        when 'dbpagesize'
          t << "olcDbPagesize: #{v}\n"
        when 'dbconfig'
          t << v.collect { |x| "olcDbConfig: #{x}" }.join("\n") + "\n"
        else
          if v.is_a?(Array)
            t << v.collect { |x| "olcDb#{k}: #{x}" }.join("\n") + "\n"
          else
            t << "olcDb#{k}: #{v}\n"
          end
        end
      end
    end
    t << resource[:syncrepl].collect { |x| "olcSyncrepl: #{x}" }.join("\n") + "\n" if resource[:syncrepl]
    t << "olcMirrorMode: #{resource[:mirrormode] == :true ? 'TRUE' : 'FALSE'}\n" if resource[:mirrormode]
    t << "olcSyncUseSubentry: #{resource[:syncusesubentry]}\n" if resource[:syncusesubentry]
    t << "#{resource[:limits].collect { |x| "olcLimits: #{x}" }.join("\n")}\n" if resource[:limits] and !resource[:limits].empty?
    t << "#{resource[:security].collect { |k, v| "olcSecurity: #{k}=#{v}" }.join("\n")}\n" if resource[:security] and !resource[:security].empty?
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
    Puppet.debug(IO.read t.path)
    begin
      ldapmodify(t.path)
    rescue Exception => e
      raise Puppet::Error, "LDIF content:\n#{IO.read t.path}\nError message: #{e.message}"
    end
    t.delete
    initdb if resource[:initdb] == :true
    @property_hash[:ensure] = :present
    slapcat("(&(objectClass=olc#{resource[:backend].to_s.capitalize}Config)(olcSuffix=#{resource[:suffix]}))").
      split("\n").collect do |line|
      if line =~ /^olcDatabase: /
        @property_hash[:index] = line.match(/^olcDatabase: \{(\d+)\}#{resource[:backend]}$/).captures[0]
      end
    end
  end

  def initialize(value={})
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
    if not @property_flush.empty?
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
        if "#{resource[:synctype]}" == "inclusive" and !@property_hash[:dboptions].empty?
          @property_hash[:dboptions].keys.each do |k|
            case k
            when 'dbnosync'
              t << "delete: olcDbNosync\n-\n"
            when 'dbpagesize'
              t << "delete: olcDbPagesize\n-\n"
            when 'dbconfig'
              t << "delete: olcDbConfig\n-\n"
            else
              t << "delete: olcDb#{k}\n-\n"
            end
          end
        end
        @property_flush[:dboptions].each do |k, v|
          case k
          when 'dbnosync'
            t << "replace: olcDbNosync\nolcDbNosync: #{v}\n-\n"
          when 'dbpagesize'
            t << "replace: olcDbPagesize\nolcDbPagesize: #{v}\n-\n"
          when 'dbconfig'
            t << "replace: olcDbConfig\n" + v.collect { |x| "olcDbConfig: #{x}" }.join("\n") + "\n-\n"
          else
            if v.is_a?(Array)
              t << "replace: olcDb#{k}\n" + v.collect { |x| "olcDb#{k}: #{x}" }.join("\n") + "\n-\n"
            else
              t << "replace: olcDb#{k}\nolcDb#{k}: #{v}\n-\n"
            end
          end
        end
      end
      t << "replace: olcSyncrepl\n#{resource[:syncrepl].collect { |x| "olcSyncrepl: #{x}" }.join("\n")}\n-\n" if @property_flush[:syncrepl]
      t << "replace: olcUpdateref\nolcUpdateref: #{resource[:updateref]}\n-\n" if @property_flush[:updateref]
      t << "replace: olcMirrorMode\nolcMirrorMode: #{resource[:mirrormode] == :true ? 'TRUE' : 'FALSE'}\n-\n" if @property_flush[:mirrormode]
      t << "replace: olcSyncUseSubentry\nolcSyncUseSubentry: #{resource[:syncusesubentry]}\n-\n" if @property_flush[:syncusesubentry]
      t << "replace: olcLimits\n#{@property_flush[:limits].collect { |x| "olcLimits: #{x}" }.join("\n")}\n-\n" if @property_flush[:limits]
      t << "replace: olcSecurity\n#{@property_flush[:security].collect { |k, v| "olcSecurity: #{k}=#{v}" }.join("\n")}\n-\n" if @property_flush[:security]
      t.close
      Puppet.debug(IO.read t.path)
      begin
        ldapmodify(t.path)
      rescue Exception => e
        raise Puppet::Error, "LDIF content:\n#{IO.read t.path}\nError message: #{e.message}"
      end
      initdb if @property_flush[:directory]
    end
    @property_hash = resource.to_hash
  end

end
