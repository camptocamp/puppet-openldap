Puppet::Type.type(:openldap_database).provide(:augeas, parent: Puppet::Type.type(:augeasprovider).provider(:default)) do
  desc 'Uses Augeas API to update OpenLDAP databases'

  default_file do
    case Facter.value(:osfamily)
    when 'Debian'
      '/etc/ldap/slapd.conf'
    when 'RedHat'
      '/etc/openldap/slapd.conf'
    when 'Archlinux'
      '/etc/openldap/slapd.conf'
    when 'FreeBSD'
      '/usr/local/etc/openldap/slapd.conf'
    when 'Suse'
      '/etc/openldap/slapd.conf'
    end
  end

  lens { 'Slapd.lns' }

  confine feature: :augeas

  resource_path do |resource|
    "$target/database[suffix = '#{resource[:name]}']"
  end

  def self.instances
    augopen do |aug|
      aug.match('$target/database').map do |hpath|
        new({
              ensure: :present,
              name: aug.get("#{hpath}/suffix").chomp('"').reverse.chomp('"').reverse,
              suffix: aug.get("#{hpath}/suffix").chomp('"').reverse.chomp('"').reverse,
              target: target,
              backend: aug.get(hpath),
              directory: aug.get("#{hpath}/directory").chomp('"').reverse.chomp('"').reverse,
              rootdn: aug.get("#{hpath}/rootdn"),
              rootpw: aug.get("#{hpath}/rootpw"),
              readonly: aug.get("#{hpath}/readonly"),
            })
      end
    end
  end

  attr_aug_accessor(:index)
  attr_aug_accessor(:backend, label: :resource)
  attr_aug_accessor(:directory)
  attr_aug_accessor(:rootdn)
  attr_aug_accessor(:rootpw)
  attr_aug_accessor(:readonly)
end
