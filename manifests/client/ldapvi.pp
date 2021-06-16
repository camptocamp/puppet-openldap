# See README.md for details.
class openldap::client::ldapvi (
  $package = 'ldapvi',
) {
  package { $package:
    ensure => present,
  }
}
