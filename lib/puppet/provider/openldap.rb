require 'tempfile'

class Puppet::Provider::Openldap < Puppet::Provider
  initvars # without this, commands won't work

  commands original_slapcat: 'slapcat',
           original_ldapmodify: 'ldapmodify',
           original_ldapadd: 'ldapadd'

  def self.slapcat(filter, dn = '', base = 'cn=config')
    arguments = [
      '-b', base,
      '-o', 'ldif-wrap=no',
      '-H', "ldap:///#{dn}???#{filter}"
    ]

    if Facter.value(:lsbdistcodename) == 'squeeze'
      arguments = [
        '-b', base,
        '-H', "ldap:///#{dn}???#{filter}"
      ]
    end

    original_slapcat(*arguments)
  end

  def slapcat(*args)
    self.class.slapcat(*args)
  end

  def self.ldapadd(path)
    original_ldapadd('-cQY', 'EXTERNAL', '-H', 'ldapi:///', '-f', path)
  end

  def ldapadd(*args)
    self.class.ldapadd(*args)
  end

  # Unwrap LDIF and return each attribute beginning with "olc" also removing
  # that occurance of "olc" at the beginning.
  def self.get_lines(items)
    items.strip.
      gsub("\n ", '').
      split("\n").
      select { |entry| entry =~ %r{^olc} }.
      map { |entry| entry.gsub(%r{^olc}, '') }
  end

  def get_lines(*args)
    self.class.get_lines(*args)
  end

  # Unwrap LDIF and return each entry as array of lines.
  #
  # Example LDIF:
  #   dn: cn=config
  #   ...
  #
  #   dn: cn=schema,cn=config
  #   ...
  #
  # Results in:
  #
  #   [['dn: cn=config', '...'],
  #    ['dn: cn=schema,cn=config', '...']]
  #
  def self.get_entries(items)
    items.strip.
      split("\n\n").
      map do |paragraph|
        paragraph.
          gsub("\n ", '').
          split("\n")
      end
  end

  def get_entries(*args)
    self.class.get_entries(*args)
  end

  def self.last_of_split(line, by = ' ')
    line.split(by, 2).last
  end

  def last_of_split(*args)
    self.class.last_of_split(*args)
  end

  def self.ldapmodify(path)
    original_ldapmodify('-Y', 'EXTERNAL', '-H', 'ldapi:///', '-f', path)
  end

  def ldapmodify(*args)
    self.class.ldapmodify(*args)
  end

  def self.temp_ldif(name = 'openldap_ldif')
    Tempfile.new(name)
  end

  def temp_ldif(*args)
    self.class.temp_ldif(*args)
  end

  def delimit
    "-\n"
  end

  def cn_config
    dn('cn=config')
  end

  def dn(dn)
    "dn: #{dn}\n"
  end

  def changetype(t)
    "changetype: #{t}\n"
  end

  def add(key)
    "add: olc#{key}\n"
  end

  def del(key)
    "delete: olc#{key}\n"
  end

  def replace_key(key)
    "replace: olc#{key}\n"
  end

  def key_value(key, value)
    "olc#{key}: #{value}\n"
  end

  def add_or_replace_key(key, force_replace = :false)
    # This list of possible attributes of cn=config has been extracted from a
    # running slapd with the following command:
    #   ldapsearch -s base -b cn=Subschema attributeTypes -o ldif-wrap=no | \
    #     grep SINGLE-VALUE | grep "NAME 'olc" | \
    #     sed -e "s|.*NAME '||g" \
    #         -e "s|' SYNTAX.*||g" \
    #         -e "s|' EQUALITY.*||g" \
    #         -e "s|' DESC.*||g"
    single_value_attributes = %w[
      ConfigFile
      ConfigDir
      AddContentAcl
      ArgsFile
      AuthzPolicy
      Backend
      Concurrency
      ConnMaxPending
      ConnMaxPendingAuth
      Database
      DefaultSearchBase
      GentleHUP
      Hidden
      IdleTimeout
      IndexSubstrIfMinLen
      IndexSubstrIfMaxLen
      IndexSubstrAnyLen
      IndexSubstrAnyStep
      IndexIntLen
      LastMod
      ListenerThreads
      LocalSSF
      LogFile
      MaxDerefDepth
      MirrorMode
      ModulePath
      Monitoring
      Overlay
      PasswordCryptSaltFormat
      PidFile
      PluginLogFile
      ReadOnly
      Referral
      ReplicaArgsFile
      ReplicaPidFile
      ReplicationInterval
      ReplogFile
      ReverseLookup
      RootDN
      RootPW
      SaslAuxprops
      SaslHost
      SaslRealm
      SaslSecProps
      SchemaDN
      SizeLimit
      SockbufMaxIncoming
      SockbufMaxIncomingAuth
      Subordinate
      SyncUseSubentry
      Threads
      TLSCACertificateFile
      TLSCACertificatePath
      TLSCertificateFile
      TLSCertificateKeyFile
      TLSCipherSuite
      TLSCRLCheck
      TLSCRLFile
      TLSRandFile
      TLSVerifyClient
      TLSDHParamFile
      TLSProtocolMin
      ToolThreads
      UpdateDN
      WriteTimeout
      DbDirectory
      DbCheckpoint
      DbNoSync
      DbMaxReaders
      DbMaxSize
      DbMode
      DbSearchStack
      PPolicyDefault
      PPolicyHashCleartext
      PPolicyForwardUpdates
      PPolicyUseLockout
      MemberOfDN
      MemberOfDangling
      MemberOfRefInt
      MemberOfGroupOC
      MemberOfMemberAD
      MemberOfMemberOfAD
      MemberOfDanglingError
      SpCheckpoint
      SpSessionlog
      SpNoPresent
      SpReloadHint
    ]

    use_replace = single_value_attributes.include?(key.to_s) || force_replace == :true

    use_replace ? replace_key(key) : add(key)
  end
end
