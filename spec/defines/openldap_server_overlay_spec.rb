require 'spec_helper'

describe 'openldap::server::overlay' do
  let(:title) { 'memberof on dc=example,dc=com' }

  let :pre_condition do
    "class {'openldap::server':}"
  end

  on_supported_os.each do |os, facts|
    context "on #{os}" do
      let(:facts) do
        facts
      end

      context 'when Class[openldap::server] is not declared' do
        let(:pre_condition) {}

        it { expect { is_expected.to compile }.to raise_error(%r{class ::openldap::server has not been evaluated}) }
      end

      context 'with ensure => present' do
        let(:params) do
          {
            ensure: 'present',
          }
        end

        it { is_expected.to compile.with_all_deps }
        it {
          is_expected.to contain_openldap_overlay('memberof on dc=example,dc=com').
            with_ensure('present').
            with_provider('olc').
            with_overlay('memberof').
            with_suffix('dc=example,dc=com')
        }
      end

      context 'with options' do
        let(:params) do
          {
            ensure: 'present',
            options: [
              'olcMemberOfGroupOC: groupOfNames',
            ],
          }
        end

        it { is_expected.to compile.with_all_deps }
        it {
          is_expected.to contain_openldap_overlay('memberof on dc=example,dc=com').
            with_ensure('present').
            with_provider('olc').
            with_overlay('memberof').
            with_suffix('dc=example,dc=com').
            with_options(['olcMemberOfGroupOC: groupOfNames'])
        }
      end
    end
  end
end
