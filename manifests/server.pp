# See README.md for details.
class openldap::server (
  $package                                          = $openldap::params::server_package,
  $confdir                                          = $openldap::params::server_confdir,
  $conffile                                         = $openldap::params::server_conffile,
  $service                                          = $openldap::params::server_service,
  Optional[Boolean] $service_hasstatus              = undef,
  $owner                                            = $openldap::params::server_owner,
  $group                                            = $openldap::params::server_group,
  $enable                                           = true,
  $start                                            = true,
  $provider                                         = 'olc',
  Optional[Stdlib::Absolutepath] $ssl_key           = undef,
  Optional[Stdlib::Absolutepath] $ssl_cert          = undef,
  Optional[Stdlib::Absolutepath] $ssl_ca            = undef,
  Hash $databases                                   = {},
  $ldap_ifs                                         = ['/'],
  $ldaps_ifs                                        = [],
  $ldapi_ifs                                        = ['/'],
  Boolean $escape_ldapi_ifs                         = $openldap::params::escape_ldapi_ifs,
  Optional[String] $slapd_params                    = undef,
  Optional[Boolean] $enable_chown                   = $openldap::params::enable_chown,
  Optional[Stdlib::Port] $ldap_port                 = undef,
  Optional[Stdlib::IP::Address] $ldap_address       = undef,
  Optional[Stdlib::Port] $ldaps_port                = undef,
  Optional[Stdlib::IP::Address] $ldaps_address      = undef,
  Optional[Stdlib::Absolutepath] $ldapi_socket_path = undef,
  Optional[Boolean] $register_slp                   = $openldap::params::register_slp,
  Optional[Stdlib::Absolutepath] $krb5_keytab_file  = undef,
  Optional[String] $ldap_config_backend             = $openldap::params::ldap_config_backend,
  Optional[Boolean] $enable_memory_limit            = $openldap::params::enable_memory_limit,
) inherits openldap::params {
  class { 'openldap::server::install': }
  -> class { 'openldap::server::config': }
  ~> class { 'openldap::server::service': }

  class { 'openldap::server::slapdconf': }

  case $provider {
    'augeas': {
      Class['openldap::server::install']
      -> Class['openldap::server::slapdconf']
      ~> Class['openldap::server::service']
      -> Class['openldap::server']
    }
    'olc': {
      Class['openldap::server::service']
      -> Class['openldap::server::slapdconf']
      -> Class['openldap::server']
    }
    default: {
      fail 'provider must be one of "olc" or "augeas"'
    }
  }
}
