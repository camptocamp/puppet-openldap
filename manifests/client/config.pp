# See README.md for details.
class openldap::client::config {
  $base = $openldap::client::base ? {
    undef    => undef,
    'absent' => 'rm BASE',
    default  => "set BASE ${openldap::client::base}",
  }
  $bind_policy = $openldap::client::bind_policy ? {
    undef    => undef,
    'absent' => 'rm BIND_POLICY',
    default  => "set BIND_POLICY ${openldap::client::bind_policy}",
  }
  $bind_timelimit = $openldap::client::bind_timelimit ? {
    undef    => undef,
    'absent' => 'rm BIND_TIMELIMIT',
    default  => "set BIND_TIMELIMIT ${openldap::client::bind_timelimit}",
  }
  $binddn = $openldap::client::binddn ? {
    undef    => undef,
    'absent' => 'rm BINDDN',
    default  => "set BINDDN ${openldap::client::binddn}",
  }
  $bindpw = $openldap::client::bindpw ? {
    undef    => undef,
    'absent' => 'rm BINDPW',
    default  => "set BINDPW ${openldap::client::bindpw}",
  }
  $ldap_version = $openldap::client::ldap_version ? {
    undef    => undef,
    'absent' => 'rm LDAP_VERSION',
    default  => "set LDAP_VERSION ${openldap::client::ldap_version}",
  }
  $network_timeout = $openldap::client::network_timeout ? {
    undef    => undef,
    'absent' => 'rm NETWORK_TIMEOUT',
    default  => "set NETWORK_TIMEOUT ${openldap::client::network_timeout}",
  }
  $scope = $openldap::client::scope ? {
    undef    => undef,
    'absent' => 'rm SCOPE',
    default  => "set SCOPE ${openldap::client::scope}",
  }
  $ssl = $openldap::client::ssl ? {
    undef    => undef,
    'absent' => 'rm SSL',
    default  => "set SSL ${openldap::client::ssl}",
  }
  $suffix = $openldap::client::suffix ? {
    undef    => undef,
    'absent' => 'rm SUFFIX',
    default  => "set SUFFIX ${openldap::client::suffix}",
  }
  $timelimit = $openldap::client::timelimit ? {
    undef    => undef,
    'absent' => 'rm TIMELIMIT',
    default  => "set TIMELIMIT ${openldap::client::timelimit}",
  }
  $timeout = $openldap::client::timeout ? {
    undef    => undef,
    'absent' => 'rm TIMEOUT',
    default  => "set TIMEOUT ${openldap::client::timeout}",
  }
  $_uri = $openldap::client::uri ? {
    undef   => undef,
    default => join(flatten([$openldap::client::uri]), ' '),
  }
  $uri = $_uri ? {
    undef    => undef,
    'absent' => 'rm URI',
    default  => "set URI '${_uri}'",
  }
  $nss_base_group = $openldap::client::nss_base_group ? {
    undef    => undef,
    'absent' => 'rm NSS_BASE_GROUP',
    default  => "set NSS_BASE_GROUP ${openldap::client::nss_base_group}",
  }
  $nss_base_hosts = $openldap::client::nss_base_hosts ? {
    undef    => undef,
    'absent' => 'rm NSS_BASE_HOSTS',
    default  => "set NSS_BASE_HOSTS ${openldap::client::nss_base_hosts}",
  }
  $nss_base_passwd = $openldap::client::nss_base_passwd ? {
    undef    => undef,
    'absent' => 'rm NSS_BASE_PASSWD',
    default  => "set NSS_BASE_PASSWD ${openldap::client::nss_base_passwd}",
  }
  $nss_base_shadow = $openldap::client::nss_base_shadow ? {
    undef    => undef,
    'absent' => 'rm NSS_BASE_SHADOW',
    default  => "set NSS_BASE_SHADOW ${openldap::client::nss_base_shadow}",
  }
  $nss_initgroups_ignoreusers = $openldap::client::nss_initgroups_ignoreusers ? {
    undef   => undef,
    default => "set NSS_INITGROUPS_IGNOREUSERS ${openldap::client::nss_initgroups_ignoreusers}",
  }
  $pam_filter = $openldap::client::pam_filter ? {
    undef    => undef,
    'absent' => 'rm PAM_FILTER',
    default  => "set PAM_FILTER ${openldap::client::pam_filter}",
  }
  $pam_login_attribute = $openldap::client::pam_login_attribute ? {
    undef    => undef,
    'absent' => 'rm PAM_LOGIN_ATTRIBUTE',
    default  => "set PAM_LOGIN_ATTRIBUTE ${openldap::client::pam_login_attribute}",
  }
  $pam_member_attribute = $openldap::client::pam_member_attribute ? {
    undef    => undef,
    'absent' => 'rm PAM_MEMBER_ATTRIBUTE',
    default  => "set PAM_MEMBER_ATTRIBUTE ${openldap::client::pam_member_attribute}",
  }
  $pam_password = $openldap::client::pam_password ? {
    undef    => undef,
    'absent' => 'rm PAM_PASSWORD',
    default  => "set PAM_PASSWORD ${openldap::client::pam_password}",
  }
  $tls_checkpeer = $openldap::client::tls_checkpeer ? {
    undef    => undef,
    'absent' => 'rm TLS_CHECKPEER',
    default  => "set TLS_CHECKPEER ${openldap::client::tls_checkpeer}",
  }
  $tls_cacert = $openldap::client::tls_cacert ? {
    undef    => undef,
    'absent' => 'rm TLS_CACERT',
    default  => "set TLS_CACERT ${openldap::client::tls_cacert}",
  }
  $tls_cacertdir = $openldap::client::tls_cacertdir ? {
    undef    => undef,
    'absent' => 'rm TLS_CACERTDIR',
    default  => "set TLS_CACERTDIR ${openldap::client::tls_cacertdir}",
  }
  $tls_reqcert = $openldap::client::tls_reqcert ? {
    undef    => undef,
    'absent' => 'rm TLS_REQCERT',
    default  => "set TLS_REQCERT ${openldap::client::tls_reqcert}",
  }
  $tls_moznss_compatibility = $openldap::client::tls_moznss_compatibility ? {
    undef    => undef,
    'absent' => 'rm TLS_MOZNSS_COMPATIBILITY',
    default  => "set TLS_MOZNSS_COMPATIBILITY ${openldap::client::tls_moznss_compatibility}",
  }
  $sasl_mech = $openldap::client::sasl_mech ? {
    undef   => undef,
    default => "set SASL_MECH ${openldap::client::sasl_mech}",
  }
  $sasl_realm = $openldap::client::sasl_realm ? {
    undef   => undef,
    default => "set SASL_REALM ${openldap::client::sasl_realm}",
  }
  $sasl_authcid = $openldap::client::sasl_authcid ? {
    undef   => undef,
    default => "set SASL_AUTHCID ${openldap::client::sasl_authcid}",
  }
  $_sasl_secprops = $openldap::client::sasl_secprops ? {
    undef   => undef,
    default => join(flatten([$openldap::client::sasl_secprops]), ','),
  }
  $sasl_secprops = $_sasl_secprops ? {
    undef   => undef,
    default => "set SASL_SECPROPS ${_sasl_secprops}",
  }
  $sasl_nocanon = $openldap::client::sasl_nocanon ? {
    undef   => undef,
    default => "set SASL_NOCANON ${openldap::client::sasl_nocanon}",
  }
  $gssapi_sign = $openldap::client::gssapi_sign ? {
    undef   => undef,
    default => "set GSSAPI_SIGN ${openldap::client::gssapi_sign}",
  }
  $gssapi_encrypt = $openldap::client::gssapi_encrypt ? {
    undef   => undef,
    default => "set GSSAPI_ENCRYPT ${openldap::client::gssapi_encrypt}",
  }
  $gssapi_allow_remote_principal = $openldap::client::gssapi_allow_remote_principal ? {
    undef   => undef,
    default => "set GSSAPI_ALLOW_REMOTE_PRINCIPAL ${openldap::client::gssapi_allow_remote_principal}",
  }
  $sudoers_base = $openldap::client::sudoers_base ? {
    undef    => undef,
    'absent' => 'rm SUDOERS_BASE',
    default  => "set SUDOERS_BASE ${openldap::client::sudoers_base}",
  }
  $changes = delete_undef_values([
      $base,
      $bind_policy,
      $bind_timelimit,
      $binddn,
      $bindpw,
      $ldap_version,
      $network_timeout,
      $scope,
      $ssl,
      $suffix,
      $timelimit,
      $timeout,
      $uri,
      $nss_base_group,
      $nss_base_hosts,
      $nss_base_passwd,
      $nss_base_shadow,
      $nss_initgroups_ignoreusers,
      $pam_filter,
      $pam_login_attribute,
      $pam_member_attribute,
      $pam_password,
      $tls_checkpeer,
      $tls_cacert,
      $tls_cacertdir,
      $tls_reqcert,
      $tls_moznss_compatibility,
      $sasl_mech,
      $sasl_realm,
      $sasl_authcid,
      $sasl_secprops,
      $sasl_nocanon,
      $gssapi_sign,
      $gssapi_encrypt,
      $gssapi_allow_remote_principal,
      $sudoers_base,
  ])
  augeas { 'ldap.conf':
    incl    => $openldap::client::file,
    lens    => 'Spacevars.lns',
    changes => $changes,
  }
}
