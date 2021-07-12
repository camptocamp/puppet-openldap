# See README.md for details.
define openldap::server::module(
  $ensure = undef,
) {

  if ! defined(Class['openldap::server']) {
    fail 'class ::openldap::server has not been evaluated'
  }

  Class['openldap::server::service']
  -> Openldap::Server::Module[$title]
  -> Class['openldap::server']

  openldap_module { $title:
    ensure   => $ensure,
  }
}
