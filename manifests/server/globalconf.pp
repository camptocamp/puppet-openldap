# See README.md for details.
define openldap::server::globalconf (
  $value,
  $ensure = 'present',
) {
  if ! defined(Class['openldap::server']) {
    fail 'class ::openldap::server has not been evaluated'
  }

  if $openldap::server::provider == 'augeas' {
    Openldap::Server::Globalconf[$title] ~> Class['openldap::server::service']
  } else {
    Class['openldap::server::service']
    -> Openldap::Server::Globalconf[$title]
    -> Class['openldap::server']
  }

  openldap_global_conf { $name:
    ensure   => $ensure,
    provider => $openldap::server::provider,
    target   => $openldap::server::conffile,
    value    => $value,
  }
}
