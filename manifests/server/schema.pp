# See README.md for details.
define openldap::server::schema(
  $ensure        = undef,
  $path          = $::osfamily ? {
    'Debian' => "/etc/ldap/schema/${title}.schema",
    'Redhat' => "/etc/openldap/schema/${title}.schema",
    'Archlinux' => "/etc/openldap/schema/${title}.schema",
    'FreeBSD' => "/usr/local/etc/openldap/schema/${title}.schema",
    'Suse' => "/etc/openldap/schema/${title}.schema",
  }
) {


  if ! defined(Class['openldap::server']) {
    fail 'class ::openldap::server has not been evaluated'
  }

  Class['openldap::server::service']
  -> Openldap::Server::Schema[$title]
  -> Class['openldap::server']
  openldap_schema { $title:
    ensure => $ensure,
    path   => $path,
  }
}
