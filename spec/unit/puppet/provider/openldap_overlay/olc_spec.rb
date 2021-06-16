require 'spec_helper'

describe Puppet::Type.type(:openldap_overlay).provider(:olc) do
  let(:params) do
    {
      title: 'memberof on dc=example,dc=com',
      name: 'memberof on dc=example,dc=com',
      overlay: 'memberof',
      suffix: 'dc=example,dc=com',
      provider: described_class.name,
    }
  end

  let(:resource) do
    Puppet::Type.type(:openldap_overlay).new(params)
  end

  let(:provider) do
    resource.provider
  end

  before do
    allow(provider).to receive(:slapcat).and_return('foo')
  end

  describe 'when creating' do
    it 'creates an overlay' do
      pending 'needs work'
      provider.create
    end
  end
end
