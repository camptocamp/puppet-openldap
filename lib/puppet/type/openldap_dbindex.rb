Puppet::Type.newtype(:openldap_dbindex) do
  @doc = 'Manages OpenLDAP DB indexes'

  ensurable

  newparam(:name) do
    desc 'The default namevar'
  end

  newparam(:target) do
    desc 'The slapd.conf file'
  end

  newparam(:suffix, namevar: true) do
    desc 'The suffix to which the index applies'
  end

  newparam(:attribute, namevar: true) do
    desc 'The attribute to index'
    defaultto('default')
  end

  def self.title_patterns
    [
      [
        %r{^((\S+)\s+on\s+(.+))$},
        [
          [:name],
          [:attribute],
          [:suffix],
        ],
      ],
      [
        %r{(.*)},
        [
          [:name],
        ],
      ],
    ]
  end

  newproperty(:indices) do
    desc 'The indices to maintain'
  end

  autorequire(:openldap_database) do
    [value(:suffix)]
  end
end
