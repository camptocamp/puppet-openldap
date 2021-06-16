require 'spec_helper'

# rubocop:disable RSpec/MessageSpies
# rubocop:disable RSpec/DescribeSymbol
describe :openldap_password do
  it { is_expected.not_to eq(nil) }

  it 'fails with wrong number of arguments' do
    is_expected.to run.with_params.and_raise_error(StandardError)
  end

  it 'generates SSHA password with only a secret' do
    expect(subject.func).to receive(:call_function).with(:fqdn_rand_string, 8).and_return('abcdefgh')
    is_expected.to run.with_params('foo').and_return('{SSHA}3RXLE64s+3ytIRdJYu9eoU8O/alhYmNkZWZnaA==')
  end

  context 'when given a secret and a scheme' do
    it 'generates CRYPT password' do
      expect(scope).to receive(:function_fqdn_rand_string).with([2]).and_return('ab')
      is_expected.to run.with_params('foo', 'CRYPT').and_return('{CRYPT}abQ9KY.KfrYrc')
    end
    it 'generates MD5 password' do
      is_expected.to run.with_params('foo', 'MD5').and_return('{MD5}acbd18db4cc2f85cedef654fccc4a4d8')
    end
    it 'generates SMD5 password' do
      expect(scope).to receive(:function_fqdn_rand_string).with([8]).and_return('abcdefgh')
      is_expected.to run.with_params('foo', 'SMD5').and_return('{SMD5}NAYSvQYSIRYBLCM8U6MUc2FiY2RlZmdo')
    end
    it 'generates SSHA password' do
      expect(scope).to receive(:function_fqdn_rand_string).with([8]).and_return('abcdefgh')
      is_expected.to run.with_params('foo', 'SSHA').and_return('{SSHA}3RXLE64s+3ytIRdJYu9eoU8O/alhYmNkZWZnaA==')
    end
    it 'generates SHA password' do
      is_expected.to run.with_params('foo', 'SHA').and_return('{SHA}0beec7b5ea3f0fdbc95d0dd47f3c5bc275da8a33')
    end
  end
end
