Puppet::Type.newtype(:openldap_overlay) do
  @doc = 'Manages OpenLDAP Overlays'

  ensurable

  newparam(:name) do
    desc 'The default namevar'
  end

  newparam(:target) do
    desc 'The slapd.conf file'
  end

  newproperty(:index) do
    desc 'The index of the overlay.'
  end

  newparam(:overlay, namevar: true) do
    desc 'The name of the overlay to apply'
  end

  newparam(:suffix, namevar: true) do
    desc 'The suffix to which the overlay applies'
  end

  def self.title_patterns
    [
      [
        %r{^((\S+)\s+on\s+(\S+))$},
        [
          [:name],
          [:overlay],
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

  newproperty(:options) do
    desc 'Overlay options.'
  end
end
