require 'spec_helper'

describe 'openldap::server::access' do
  let(:title) { 'foo' }

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

      context 'with composite namevar' do
        let(:title) do
          'to attrs=userPassword,shadowLastChange by dn="cn=admin,dc=example,dc=com" on dc=example,dc=com'
        end

        it { is_expected.to compile.with_all_deps }
        it {
          is_expected.to contain_openldap_access('to attrs=userPassword,shadowLastChange by dn="cn=admin,dc=example,dc=com" on dc=example,dc=com')
        }
      end

      context 'with composite namevar, what includes dn and filter' do
        let(:title) do
          'to dn.one="ou=users,dc=example,dc=com" filter=(objectClass=person) by dn="cn=admin,dc=example,dc=com" on dc=example,dc=com'
        end

        it { is_expected.to compile.with_all_deps }
        it {
          is_expected.to contain_openldap_access('to dn.one="ou=users,dc=example,dc=com" filter=(objectClass=person) by dn="cn=admin,dc=example,dc=com" on dc=example,dc=com')
        }
      end

      context 'with composite namevar, what includes dn and attrs' do
        let(:title) do
          'to dn.one="ou=users,dc=example,dc=com" attrs=userPassword,shadowLastChange by dn="cn=admin,dc=example,dc=com" on dc=example,dc=com'
        end

        it { is_expected.to compile.with_all_deps }
        it {
          is_expected.to contain_openldap_access('to dn.one="ou=users,dc=example,dc=com" attrs=userPassword,shadowLastChange by dn="cn=admin,dc=example,dc=com" on dc=example,dc=com')
        }
      end

      context 'with composite namevar, what includes dn, filter and attrs' do
        let(:title) do
          'to dn.one="ou=users,dc=example,dc=com" filter=(objectClass=person) attrs=userPassword,shadowLastChange by dn="cn=admin,dc=example,dc=com" on dc=example,dc=com'
        end

        it { is_expected.to compile.with_all_deps }
        it {
          is_expected.to contain_openldap_access('to dn.one="ou=users,dc=example,dc=com" filter=(objectClass=person) attrs=userPassword,shadowLastChange by dn="cn=admin,dc=example,dc=com" on dc=example,dc=com')
        }
      end

      context 'with composite namevar with position' do
        let(:title) do
          '{0}to attrs=userPassword,shadowLastChange by dn="cn=admin,dc=example,dc=com" on dc=example,dc=com'
        end

        it { is_expected.to compile.with_all_deps }
        it {
          is_expected.to contain_openldap_access('{0}to attrs=userPassword,shadowLastChange by dn="cn=admin,dc=example,dc=com" on dc=example,dc=com')
        }
      end

      context 'with access as an array' do
        let(:params) do
          {
            position: '0',
            what: 'to attrs=userPassword,shadowLastChange',
            suffix: 'dc=example,dc=com',
            access: [
              'by dn="cn=admin,dc=example,dc=com" write',
              'by anonymous read',
            ],
          }
        end

        it { is_expected.to compile.with_all_deps }
        it {
          is_expected.to contain_openldap_access('foo').
            with_position('0').
            with_what('to attrs=userPassword,shadowLastChange').
            with_suffix('dc=example,dc=com').
            with_access(['by dn="cn=admin,dc=example,dc=com" write', 'by anonymous read'])
        }
      end
    end
  end
end
