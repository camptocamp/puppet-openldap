# See README.md for details.
class openldap::utils(
  $package,
) {
  if $package {
    package { $package:
      ensure => present,
    }
  }
}
