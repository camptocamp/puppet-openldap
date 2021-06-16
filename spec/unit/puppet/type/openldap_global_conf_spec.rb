require 'spec_helper'

describe Puppet::Type.type(:openldap_global_conf) do
  on_supported_os.each do |os, facts|
    context "on #{os}" do
      let(:facts) { facts }

      describe 'when validating attributes' do
        [:name, :provider, :target].each do |param|
          it "should have a #{param} parameter" do
            expect(described_class.attrtype(param)).to eq(:param)
          end
        end
        [:ensure, :value].each do |prop|
          it "should have a #{prop} property" do
            expect(described_class.attrtype(prop)).to eq(:property)
          end
        end
      end
    end
  end
end
