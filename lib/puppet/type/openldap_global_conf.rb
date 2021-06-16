Puppet::Type.newtype(:openldap_global_conf) do
  ensurable

  newparam(:name) do
  end

  newparam(:target) do
  end

  newproperty(:value) do
    validate do |value|
      raise Puppet::Error, 'value should be a String or a Hash' unless [String, Hash].include? value.class
    end
  end
end
