# See README.md for details.
class openldap::utils (
  $package = $openldap::params::utils_package,
) inherits openldap::params {
  if $package {
    package { $package:
      ensure => present,
    }
  }
}
