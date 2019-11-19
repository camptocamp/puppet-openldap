require 'spec_helper_acceptance'

describe 'openldap::server::access' do
  before :all do
    pp = <<-EOS
      class { 'openldap::server': }
      openldap::server::database { 'dc=example,dc=com':
        ensure => absent,
      }
    EOS

    apply_manifest(pp, catch_failures: true)
    apply_manifest(pp, catch_changes: true)
  end

  after :all do
    pp = <<-EOS
      class { 'openldap::server': }
      openldap::server::database { 'dc=example,dc=com': ensure => absent, }
    EOS

    apply_manifest(pp, expect_changes: true)
    apply_manifest(pp, catch_changes: true)
  end

  context 'with defaults' do
    it 'idempotentlies run' do
      pp = <<-EOS
        class { 'openldap::server': }
        openldap::server::database { 'dc=example,dc=com' : }
        ::openldap::server::access { 'admin':
          what    => 'attrs=userPassword,distinguishedName',
          access  => ['by dn="cn=admin,dc=example,dc=com" write'],
          suffix  => 'dc=example,dc=com',
          require => Openldap::Server::Database['dc=example,dc=com'],
        }
        ::openldap::server::access { 'root':
          what    => '*',
          access  => [
            'by dn.exact=gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth manage',
            'by * break'
          ],
          suffix  => 'dc=example,dc=com',
          position => 0,
          require => Openldap::Server::Database['dc=example,dc=com'],
        }
      EOS

      apply_manifest(pp, catch_failures: true)
      apply_manifest(pp, catch_changes: true)
    end
  end
end
