Puppet::Type.newtype(:openldap_schema) do
  @doc = 'Manages OpenLDAP schemas.'

  ensurable

  newparam(:name) do
    desc 'The default namevar.'
  end

  newparam(:path) do
    desc 'The location to the schema file.'
    validate do |value|
      raise("Invalid file type #{value}") unless value =~ %r{.*(\.ldif|\.schema)$}i
    end
  end

  newproperty(:index) do
    desc 'The index of the schema.'
  end

  newproperty(:date) do
    desc 'The modifyTimestamp of the schema.'
  end
end
