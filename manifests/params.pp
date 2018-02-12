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
      if $::operatingsystem == 'Debian' and versioncmp($::operatingsystemmajrelease, '5') <= 0 {
        $server_service_hasstatus = false
      } else {
        $server_service_hasstatus = true
      }
      $utils_package            = 'ldap-utils'
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
      $server_service_hasstatus = true
      $utils_package            = 'openldap-clients'
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
      $server_service_hasstatus = true
      $utils_package            = undef
    }
    'FreeBSD': {
      $client_package           = 'net/openldap24-client'
      $client_package_settings  = {'GSSAPI'=> true}
      $client_conffile          = '/usr/local/etc/openldap/ldap.conf'
      $server_confdir           = '/usr/local/etc/openldap/slapd.d'
      $server_conffile          = '/usr/local/etc/openldap/slapd.conf'
      $server_group             = 'ldap'
      $server_owner             = 'ldap'
      $server_package           = 'net/openldap24-server'
      $server_package_settings  = {'SASL' => true, 'GSSAPI'=> true}
      $server_service           = 'slapd'
      $server_service_hasstatus = true
      $utils_package            = undef
      $package_provider         = 'portsng'
    }
    default: {
      fail "Operating System family ${::osfamily} not supported"
    }
  }
}
