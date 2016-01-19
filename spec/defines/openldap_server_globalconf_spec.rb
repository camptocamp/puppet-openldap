require 'spec_helper'

describe 'openldap::server::globalconf' do

  let(:title) { 'foo' }

  on_supported_os.each do |os, facts|
    context "on #{os}" do
      let(:facts) do
        facts
      end

      context 'without value' do
        it { expect { is_expected.to compile } }
      end

      context 'with a string value' do
        let(:params) {{ :value => 'bar' }}

        context 'with olc provider' do

          context 'with no parameters' do
            let :pre_condition do
              "class { 'openldap::server': }"
            end

            it { is_expected.to compile.with_all_deps }
            it { is_expected.to contain_openldap__server__globalconf('foo').with({
              :value => 'bar',
            })}
          end
        end
      end

      context 'with an array value' do

        let(:params) {{ :value => ['bar', 'boo', 'baz'].sort }}

        context 'with olc provider' do
          context 'with no parameters' do
            let :pre_condition do
              "class { 'openldap::server': }"
            end

            it { is_expected.to compile.with_all_deps }
            it { is_expected.to contain_openldap__server__globalconf('foo').with({
              :value => ['bar', 'boo', 'baz'].sort,
            })}
          end
        end
      end
    end
  end
end
