require 'spec_helper_acceptance'

describe 'openldap::server::database' do
  before :all do
    pp = <<-EOS
      class { 'openldap::server': }
      openldap::server::database { 'dc=foo,dc=com':
        ensure => absent,
      }
      openldap::server::database { 'cn=config':
        rootdn    => 'cn=admin,cn=config',
        backend   => 'config',
        rootpw    => 'secret',
      }
    EOS

    idempotent_apply(pp)
  end

  after :all do
    pp = <<-EOS
      class { 'openldap::server': }
      openldap::server::database { ['dc=foo,dc=com', 'dc=bar,dc=com']:
        ensure => absent,
      }
      openldap::server::database { 'cn=config':
        rootdn    => 'cn=admin,cn=config',
        backend   => 'config',
        rootpw    => 'secret',
      }
    EOS

    idempotent_apply(pp)
  end

  context 'without parameters' do
    it 'creates a database' do
      pp = <<-EOS
      class { 'openldap::server': }
      openldap::server::database { 'dc=foo,dc=com': }
      EOS

      idempotent_apply(pp)
    end

    it 'can connect with ldapsearch' do
      ldapsearch('-LLL -x -b dc=foo,dc=com') do |r|
        expect(r.stdout).to match(%r{dn: dc=foo,dc=com})
      end
    end
  end

  context 'with a directory' do
    it 'creates a database' do
      Dir.mktmpdir('openldap') do |tmpdir|
        pp = <<-EOS
        class { 'openldap::server': }
        openldap::server::database { 'dc=bar,dc=com':
          directory => '#{tmpdir}',
        }
        EOS

        idempotent_apply(pp)
      end
    end

    it 'can connect with ldapsearch' do
      ldapsearch('-LLL -x -b dc=bar,dc=com') do |r|
        expect(r.stdout).to match(%r{dn: dc=bar,dc=com})
      end
    end
  end

  context 'with a rootdn and rootpw' do
    it 'creates a database' do
      Dir.mktmpdir('openldap') do |tmpdir|
        pp = <<-EOS
        class { 'openldap::server': }
        openldap::server::database { 'dc=bar,dc=com':
          ensure    => present,
          directory => '#{tmpdir}',
          rootdn    => 'cn=admin,dc=bar,dc=com',
          rootpw    => 'secret',
        }
        EOS

        idempotent_apply(pp)
      end
    end

    it 'can connect with ldapsearch' do
      ldapsearch('-LLL -x -b "dc=foo,dc=com" -D "cn=admin,dc=bar,dc=com" -w secret') do |r|
        expect(r.stdout).to match(%r{dn: dc=foo,dc=com})
      end
    end
  end

  context 'with a monitor db' do
    it 'creates a monitor database' do
      pp = <<-EOS
      class {'openldap::server': }
      openldap::server::module {'back_monitor':
        ensure => present,
      }
      openldap::server::database { 'cn=monitor':
        ensure => present,
        backend => 'monitor',
        require => Openldap::Server::Module['back_monitor'],
      }
      EOS

      idempotent_apply(pp)
    end
  end

  context 'with a ldap db' do
    it 'creates a ldap database' do
      pp = <<-EOS
      class {'openldap::server': }
      openldap::server::module {'back_ldap':
        ensure => present,
      }
      openldap::server::database { 'dc=bar,dc=com':
        ensure => present,
        backend => 'ldap',
        require => Openldap::Server::Module['back_ldap'],
      }
      EOS

      pending 'Somehow this test does not work.'
      idempotent_apply(pp)
    end
  end

  context 'cn=config with a rootdn and rootpw' do
    it 'change a config password database' do
      pp = <<-EOS
      class { 'openldap::server': }
      openldap::server::database { 'cn=config':
        ensure    => present,
        backend   => 'config',
        rootdn    => 'cn=newadmin,cn=config',
        rootpw    => 'newsecret',
      }
      EOS

      idempotent_apply(pp)
    end

    it 'can connect with ldapsearch to the new password' do
      ldapsearch('-LLL -s base -x -b "cn=config" -D "cn=newadmin,cn=config" -w newsecret') do |r|
        expect(r.stdout).to match(%r{dn: cn=config})
      end
    end
  end
end
