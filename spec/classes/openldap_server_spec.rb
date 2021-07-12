require 'spec_helper'

describe 'openldap::server' do
  on_supported_os.each do |os, facts|
    context "on #{os}" do
      let(:facts) do
        facts
      end

      context 'with olc provider' do
        context 'with no parameters' do
          it { is_expected.to compile.with_all_deps }
          it {
            is_expected.to contain_class('openldap::server::install')
              .that_comes_before('Class[openldap::server::config]')
          }
          it {
            is_expected.to contain_class('openldap::server::config')
              .that_notifies('Class[openldap::server::service]')
          }
          it {
            is_expected.to contain_class('openldap::server::service')
              .that_comes_before('Class[openldap::server::slapdconf]')
          }
          it {
            is_expected.to contain_class('openldap::server::slapdconf')
              .that_comes_before('Class[openldap::server]')
          }
          case facts[:osfamily]
          when 'Debian'
            it {
              is_expected.to contain_class('openldap::server').with(package: 'slapd',
                                                                    service: 'slapd',
                                                                    enable: true,
                                                                    start: true,
                                                                    ssl_cert: nil,
                                                                    ssl_key: nil,
                                                                    ssl_ca: nil)
            }
            it { is_expected.to contain_openldap__server__database('dc=my-domain,dc=com').with(ensure: :absent) }
            it { is_expected.to have_openldap__server__database_resource_count(1) }
          when 'RedHat'
            case facts[:operatingsystemmajrelease]
            when '5'
              it {
                is_expected.to contain_class('openldap::server').with(package: 'openldap-servers',
                                                                      service: 'ldap',
                                                                      enable: true,
                                                                      start: true,
                                                                      ssl_cert: nil,
                                                                      ssl_key: nil,
                                                                      ssl_ca: nil)
              }
              it { is_expected.to have_openldap__server__database_resource_count(0) }
            else
              it {
                is_expected.to contain_class('openldap::server').with(package: 'openldap-servers',
                                                                      service: 'slapd',
                                                                      enable: true,
                                                                      start: true,
                                                                      ssl_cert: nil,
                                                                      ssl_key: nil,
                                                                      ssl_ca: nil)
              }
              it { is_expected.to have_openldap__server__database_resource_count(0) }
            end
          end
        end
      end
    end
  end
end
