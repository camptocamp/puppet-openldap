require 'spec_helper'

# rubocop:disable RSpec/RepeatedExample
describe 'openldap::server::service' do
  on_supported_os.each do |os, facts|
    context "on #{os}" do
      let(:facts) do
        facts
      end

      context 'with no parameters' do
        let :pre_condition do
          "class {'openldap::server':}"
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_class('openldap::server::service') }
        case facts[:osfamily]
        when 'Debian'
          it {
            is_expected.to contain_service('slapd').with(ensure: :running,
                                                         enable: true)
          }
        when 'RedHat'
          case facts[:operatingsystemmajrelease]
          when '5'
            it {
              is_expected.to contain_service('ldap').with(ensure: :running,
                                                          enable: true)
            }
          else
            it {
              is_expected.to contain_service('slapd').with(ensure: :running,
                                                           enable: true)
            }
          end
        end
      end
    end
  end
end
