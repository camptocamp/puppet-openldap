# See README.md for details.
class openldap::params {
  case $::osfamily {
    'Debian': {
      $client_package           = 'libldap-2.4-2'
      $client_conffile          = '/etc/ldap/ldap.conf'
      $server_confdir           = '/etc/ldap/slapd.d'
      $server_conffile          = '/etc/ldap/slapd.conf'
      $server_group             = 'openldap'
      $server_owner             = 'openldap'
      $server_package           = 'slapd'
      $server_service           = 'slapd'
      $utils_package            = 'ldap-utils'
      $escape_ldapi_ifs         = false
      # added to fix spec tests
      $enable_chown             = undef
      $register_slp             = undef
      $ldap_config_backend      = undef
      $enable_memory_limit      = undef
    }
    'RedHat': {
      $client_package           = 'openldap'
      $client_conffile          = '/etc/openldap/ldap.conf'
      $server_confdir           = '/etc/openldap/slapd.d'
      $server_conffile          = '/etc/openldap/slapd.conf'
      $server_group             = 'ldap'
      $server_owner             = 'ldap'
      $server_package           = 'openldap-servers'
      $server_service           = $::operatingsystemmajrelease ? {
        '5' => 'ldap',
        default => 'slapd',
      }
      $utils_package            = 'openldap-clients'
      $escape_ldapi_ifs         = false
      # added to fix spec tests
      $enable_chown             = undef
      $register_slp             = undef
      $ldap_config_backend      = undef
      $enable_memory_limit      = undef
    }
    'Archlinux': {
      $client_package           = 'openldap'
      $client_conffile          = '/etc/openldap/ldap.conf'
      $server_confdir           = '/etc/openldap/slapd.d'
      $server_conffile          = '/etc/openldap/slapd.conf'
      $server_group             = 'ldap'
      $server_owner             = 'ldap'
      $server_package           = 'openldap'
      $server_service           = 'slapd'
      $utils_package            = undef
      $escape_ldapi_ifs         = false
      # added to fix spec tests
      $enable_chown             = undef
      $register_slp             = undef
      $ldap_config_backend      = undef
      $enable_memory_limit      = undef
    }
    'FreeBSD': {
      $client_package           = 'openldap-sasl-client'
      $client_conffile          = '/usr/local/etc/openldap/ldap.conf'
      $server_confdir           = '/usr/local/etc/openldap/slapd.d'
      $server_conffile          = '/usr/local/etc/openldap/slapd.conf'
      $server_group             = 'ldap'
      $server_owner             = 'ldap'
      $server_package           = 'openldap-sasl-server'
      $server_service           = 'slapd'
      $utils_package            = undef
      $escape_ldapi_ifs         = true
      # added to fix spec tests
      $enable_chown             = undef
      $register_slp             = undef
      $ldap_config_backend      = undef
      $enable_memory_limit      = undef
    }
    'Suse': {
      $client_package           = 'openldap2-client'
      $client_conffile          = '/etc/openldap/ldap.conf'
      $server_confdir           = '/etc/openldap/slapd.d'
      $server_conffile          = '/etc/openldap/slapd.conf'
      $server_group             = 'ldap'
      $server_owner             = 'ldap'
      $server_package           = 'openldap2'
      $server_service           = 'slapd'
      $utils_package            = undef
      $escape_ldapi_ifs         = true
      $enable_chown             = true
      $register_slp             = true
      $ldap_config_backend      = 'files'
      $enable_memory_limit      = true
    }
    default: {
      fail "Operating System family ${::osfamily} not supported"
    }
  }
}
