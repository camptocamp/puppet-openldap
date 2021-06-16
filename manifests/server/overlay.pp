# See README.md for details.
define openldap::server::overlay (
  $ensure  = present,
  $overlay = regsubst($title, '^(\S+)\s+on\s+(\S+)$', '\1'),
  $suffix  = regsubst($title, '^(\S+)\s+on\s+(\S+)$', '\2'),
  $options = undef,
) {
  if ! defined(Class['openldap::server']) {
    fail 'class ::openldap::server has not been evaluated'
  }

  if $openldap::server::provider == 'augeas' {
    Class['openldap::server::install']
    -> Openldap::Server::Overlay[$title]
    ~> Class['openldap::server::service']
  } else {
    Class['openldap::server::service']
    -> Openldap::Server::Overlay[$title]
    -> Class['openldap::server']
  }

  openldap_overlay { "${overlay} on ${suffix}":
    ensure   => $ensure,
    provider => $openldap::server::provider,
    overlay  => $overlay,
    suffix   => $suffix,
    options  => $options,
  }
}
