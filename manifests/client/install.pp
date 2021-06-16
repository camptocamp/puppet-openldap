# See README.md for details.
class openldap::client::install {
  if ! defined(Class['openldap::client']) {
    fail 'class ::openldap::client has not been evaluated'
  }

  package { $openldap::client::package:
    ensure => present,
  }
}
