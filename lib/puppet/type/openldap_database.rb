require 'puppet/property/boolean'

# rubocop:disable Style/RegexpLiteral
# rubocop:disable Lint/ParenthesesAsGroupedExpression
# rubocop:disable Style/PredicateName
Puppet::Type.newtype(:openldap_database) do
  @doc = 'Manages OpenLDAP BDB and HDB databases.'

  ensurable

  newparam(:suffix, namevar: true) do
    desc 'The default namevar.'
  end

  newparam(:relay) do
    desc 'The relay configuration.'
  end

  newparam(:target) do
  end

  newproperty(:index) do
    desc 'The index of the database.'
  end

  newproperty(:backend) do
    desc 'The name of the backend.'
    newvalues('bdb', 'hdb', 'mdb', 'monitor', 'config', 'relay', 'ldap')
    defaultto do
      case Facter.value(:osfamily)
      when 'Debian'
        case Facter.value(:operatingsystem)
        when 'Debian'
          if Facter.value(:operatingsystemmajrelease).to_i <= 7
            'hdb'
          else
            'mdb'
          end
        when 'Ubuntu'
          if Facter.value(:operatingsystemmajrelease).to_i <= 15
            'hdb'
          else
            'mdb'
          end
        else
          'hdb'
        end
      when 'RedHat'
        if Facter.value(:operatingsystemmajrelease).to_i <= 6
          'bdb'
        else
          'hdb'
        end
      when 'FreeBSD'
        'mdb'
      end
    end
  end

  newproperty(:directory) do
    desc 'The directory where the BDB files containing this database and associated indexes live.'
    defaultto do
      unless %w[monitor config relay ldap].include? (@resource[:backend]).to_s
        '/var/lib/ldap'
      end
    end
  end

  newproperty(:rootdn) do
    desc 'The distinguished name that is not subject to access control or administrative limit restrictions for operations on this database.'
  end

  newproperty(:rootpw) do
    desc 'Password (or hash of the password) for the rootdn.'

    def insync?(is)
      if should =~ %r{^\{(CRYPT|MD5|SMD5|SSHA|SHA(256|384|512)?)\}.+}
        should == is
      else
        case is
        when %r{^\{CRYPT\}.+}
          '{CRYPT}' + should.crypt(is[0, 2]) == is
        when %r{^\{MD5\}.+}
          '{MD5}' + Digest::MD5.hexdigest(should) == is
        when %r{^\{SMD5\}.+}
          salt = is[16..-1]
          md5_hash_with_salt = "#{Digest::MD5.digest(should + salt)}#{salt}"
          is == "{SMD5}#{[md5_hash_with_salt].pack('m').delete("\n")}"
        when %r{^\{SSHA\}.+}
          decoded = Base64.decode64(is.gsub(%r{^\{SSHA\}}, ''))
          salt = decoded[20..-1]
          '{SSHA}' + Base64.encode64("#{Digest::SHA1.digest("#{should}#{salt}")}#{salt}").chomp == is
        when %r{^\{SHA\}.+}
          '{SHA}' + Digest::SHA1.hexdigest(should) == is
        when %r{^\{(SHA(256|384|512))\}}
          matches = is.match("^\{(SHA[\\d]{,3})\}")
          raise ArgumentError, "Invalid password format: #{is}" if matches.nil?
          crypto = matches[1]
          case crypto
          when 'SHA256'
            '{SHA256}' + Digest::SHA256.hexdigest(should) == is
          when 'SHA384'
            '{SHA384}' + Digest::SHA384.hexdigest(should) == is
          when 'SHA512'
            '{SHA512}' + Digest::SHA512.hexdigest(should) == is
          end
        else
          false
        end
      end
    end

    def sync
      require 'securerandom'
      salt = SecureRandom.random_bytes(4)
      @resource[:rootpw] = if should =~ %r{^\{(CRYPT|MD5|SMD5|SSHA|SHA(256|384|512)?)\}.+}
                             should
                           else
                             '{SSHA}' + Base64.encode64("#{Digest::SHA1.digest("#{should}#{salt}")}#{salt}").chomp
                           end
      super
    end

    def change_to_s(currentvalue, _newvalue)
      if currentvalue == :absent
        'created password'
      else
        'changed password'
      end
    end

    def is_to_s(_currentvalue)
      '[old password hash redacted]'
    end

    def should_to_s(_newvalue)
      '[new password hash redacted]'
    end
  end

  newparam(:initdb, boolean: true) do
    desc 'When true it initiales the database with the top object. When false, it does not create any object in the database, so you have to create it by other mechanism. It defaults to true'

    newvalues(:true, :false)
    defaultto do
      if %w[monitor config relay ldap].include? (@resource[:backend]).to_s
        :false
      else
        :true
      end
    end
  end

  newproperty(:readonly) do
    desc 'Puts the database into read-only mode.'
  end

  newproperty(:sizelimit) do
    desc 'Specifies the maximum number of entries to return from a search operation.'
  end

  newproperty(:dbmaxsize) do
    desc 'Specifies the maximum size of the DB in bytes.'
  end

  newproperty(:timelimit) do
    desc 'Specifies the maximum number of seconds (in real time) slapd will spend answering a search request.'
  end

  newproperty(:updateref) do
    desc 'This directive is only applicable in a slave slapd. It specifies the URL to return to clients which submit update requests upon the replica.'
  end

  newproperty(:dboptions) do
    desc 'Hash to pass specific HDB/BDB options for the database'

    def insync?(is)
      if resource[:synctype] == :inclusive
        is == should
      else
        should.each do |k, _v|
          return false if is[k] != should[k]
        end
      end
    end
  end

  newparam(:synctype) do
    desc "Whether specified dboptions should be considered the complete list (inclusive) or the minimum list (minimum) of dboptions the database should have. Defaults to minimum.

    Valid values are inclusive, minimum."

    newvalues(:inclusive, :minimum)
    defaultto :minimum
  end

  newproperty(:mirrormode, boolean: true) do
    desc 'This option puts a replica database into "mirror" mode'
    newvalues(:true, :false)
  end

  newproperty(:syncusesubentry) do
    desc 'Store the syncrepl contextCSN in a subentry instead of the context entry of the database'
  end

  newproperty(:syncrepl, array_matching: :all) do
    desc 'Specify the current database as a replica which is kept up-to-date with the master content by establishing the current slapd(8) as a replication consumer site running a syncrepl replication engine.'
  end

  newproperty(:limits, array_matching: :all) do
    desc 'Limits the number entries returned and/or the time spent by a request'

    validate do |value|
      if value !~ /^(\*|anonymous|users|self|(dn(\.\S+)?=\S+)|(dn\.\S+=\S+)|(group(\/\S+(\/\S+)?)?=\S+))(\s+((time(\.(soft|hard))?=((\d+)|unlimited))|(size(\.(soft|hard|unchecked))?=((\d+)|unlimited))|(size\.pr=((\d+)|noEstimate|unlimited))|(size.prtotal=((\d+)|unlimited|disabled))))+$/
        raise ArgumentError, "Invalid limit: #{value}\nLimit values must be according to syntax described at http://www.openldap.org/doc/admin24/limits.html#Per-Database%20Limits"
      end
    end
  end

  newproperty(:security) do
    desc 'The olcSecurity configuration.'
    correct_keys = %w[transport sasl simple_bind ssf tls update_sasl update_ssf update_tls update_transport]
    validate do |value|
      value.each do |k, v|
        unless correct_keys.include? k
          raise ArgumentError, "Invalid security key: '#{k}' for value '#{v}'\nSecurity key must be one of these value: #{correct_keys.join(', ')}\nSee olcSecurity in `man slapd-config`"
        end
        next if Float(v)

        raise ArgumentError, "Invalid security value: '#{v}' for key '#{k}'\nSecurity value must be a number\nSee olcSecurity in `man slapd-config`"
      end
    end
  end
end
