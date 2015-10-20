Puppet::Type.newtype(:openldap_access) do
  @doc = 'Manages OpenLDAP ACPs/ACLs'

  ensurable

  newparam(:name) do
    desc "The default namevar"
  end

  newparam(:target) do
    desc "The slapd.conf file"
  end

  newproperty(:what) do
    desc "The entries and/or attributes to which the access applies"
  end

  newproperty(:by) do
    desc "To whom the access applies"
  end

  newproperty(:suffix) do
    desc "The suffix to which the access applies"
  end

  def self.title_patterns
    [
      [
        /^(to\s+(\S+)\s+by\s+(.+)\s+on\s+(.+))$/,
        [
          [ :name, lambda{|x| x} ],
          [ :what, lambda{|x| x} ],
          [ :by, lambda{|x| x} ],
          [ :suffix, lambda{|x| x} ],
        ],
      ],
      [
        /^(to\s+(\S+)\s+by\s+(.+))$/,
        [
          [ :name, lambda{|x| x} ],
          [ :what, lambda{|x| x} ],
          [ :by, lambda{|x| x} ],
        ],
      ],
      [
        /(.*)/,
        [
          [ :name, lambda{|x| x} ],
        ],
      ],
    ]
  end

  newproperty(:position) do
    desc "Where to place the new entry"
  end

  newproperty(:access) do
    desc "Access rule."
  end

  newproperty(:control) do
    desc "Control rule."
  end

  autorequire(:openldap_database) do
    [ value(:suffix) ]
  end

end
