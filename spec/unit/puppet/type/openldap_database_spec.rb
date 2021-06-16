require 'spec_helper'

# rubocop:disable RSpec/InstanceVariable
describe Puppet::Type.type(:openldap_database) do
  before do
    @provider_class = described_class.provide(:simple) { mk_resource_methods }
    allow(@provider_class).to receive(:suitable?).and_return(true)
    allow(described_class).to receive(:defaultprovider).and_return(@provider_class)
  end

  describe 'namevar validation' do
    it 'has :suffix as its namevar' do
      expect(described_class.key_attributes).to eq([:suffix])
    end
    it 'does not invalid suffixes' do
      skip('must implement validation')
      expect { described_class.new(name: 'foo bar') }.to raise_error(Puppet::Error, %r{Invalid value})
      expect { described_class.new(name: 'cn=admin,dc=example,dc=com') }.to raise_error(Puppet::Error, %r{Invalid value})
      expect { described_class.new(name: 'dc=example, dc=com') }.to raise_error(Puppet::Error, %r{Invalid value})
    end
    it 'allows valid suffix' do
      expect { described_class.new(name: 'dc=example,dc=com') }.not_to raise_error
      expect { described_class.new(name: 'cn=config') }.not_to raise_error
    end
  end

  describe 'when validating attributes' do
    [:suffix, :provider].each do |param|
      it "should have a #{param} parameter" do
        expect(described_class.attrtype(param)).to eq(:param)
      end
    end

    [:backend, :directory].each do |property|
      it "should have a #{property} property" do
        expect(described_class.attrtype(property)).to eq(:property)
      end
    end
  end

  describe 'when validating values' do
    describe 'ensure' do
      it 'supports present as a value for ensure' do
        expect { described_class.new(name: 'foo', ensure: :present) }.not_to raise_error
      end
      it 'supports absent as a value for ensure' do
        expect { described_class.new(name: 'foo', ensure: :absent) }.not_to raise_error
      end
      it 'does not support other values' do
        expect { described_class.new(name: 'foo', ensure: :foo) }.to raise_error(Puppet::Error, %r{Invalid value})
      end
    end

    describe 'backend' do
      %w[bdb hdb mdb monitor config relay ldap].each do |b|
        it "should support #{b} as a value for backend" do
          expect { described_class.new(name: 'foo', backend: b) }.not_to raise_error
        end
      end
      it 'supports config as a value for backend' do
        expect { described_class.new(name: 'foo', backend: 'config') }.not_to raise_error
      end
      it 'does not support other values' do
        expect { described_class.new(name: 'foo', backend: 'bar') }.to raise_error(Puppet::Error, %r{Invalid value})
      end
    end

    describe 'directory' do
      it 'supports an absolute path as a value for directory' do
        expect { described_class.new(name: 'foo', directory: '/bar/baz') }.not_to raise_error
      end
      it 'does not support other values' do
        skip('Must implement validation')
        expect { described_class.new(name: 'foo', directory: 'bar/baz') }.to raise_error(Puppet::Error, %r{kjsflkjdsflk})
      end
    end
  end

  describe 'rootpw' do
    before do
      @resource = described_class.new(name: 'foo')
      @password = described_class.attrclass(:rootpw).new(resource: @resource, should: 'secret')
    end

    it 'does not include the password in the change log when adding the password' do
      expect(@password.change_to_s(:absent, 'secret')).not_to be_include('secret')
    end

    it 'does not include the password in the change log when changing the password' do
      expect(@password.change_to_s('oldpass', 'secret')).not_to be_include('secret')
    end

    it 'redacts the password when displaying the old value' do
      expect(@password.is_to_s('oldpass')).to match(%r{^\[old password hash redacted\]$})
    end

    it 'redacts the password when displaying the new value' do
      expect(@password.should_to_s('newpass')).to match(%r{^\[new password hash redacted\]$})
    end
  end
end
