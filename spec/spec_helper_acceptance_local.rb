def ldapsearch(_cmd, _exit_codes = [0, 1])
  puts 'shell() not working in litmus for now'
  # shell("ldapsearch #{cmd}", acceptable_exit_codes: exit_codes, &block)
end

RSpec.configure do |c|
  c.before :suite do
    run_shell('puppet cert generate $(facter fqdn) || true')
    pp = <<-EOS
     $ssldir = '/etc/puppetlabs/puppet/ssl'
     file { '/etc/ldap':
       ensure => directory,
     }
     file { '/etc/ldap/ssl':
       ensure => directory,
     }
     if $::osfamily == 'Debian' {
       # OpenLDAP is linked towards GnuTLS on Debian so we have to convert the key
       package { 'gnutls-bin':
         ensure => present,
       }
       ->
       exec { "certtool -k < ${ssldir}/private_keys/${::fqdn}.pem > /etc/ldap/ssl/${::fqdn}.key":
         creates => "/etc/ldap/ssl/${::fqdn}.key",
         path    => $::path,
         require => File['/etc/ldap/ssl'],
         before  => File["/etc/ldap/ssl/${::fqdn}.key"],
       }
     } else {
       File <| title == "/etc/ldap/ssl/${::fqdn}.key" |> {
         source => "${ssldir}/private_keys/${::fqdn}.pem",
       }
     }
     file { "/etc/ldap/ssl/${::fqdn}.key":
       ensure  => file,
       mode    => '0644',
     }
     file { "/etc/ldap/ssl/${::fqdn}.crt":
       ensure  => file,
       mode    => '0644',
       source  => "${ssldir}/certs/${::fqdn}.pem",
     }
     file { '/etc/ldap/ssl/ca.pem':
       ensure  => file,
       mode    => '0644',
       source  => "${ssldir}/certs/ca.pem",
     }
    EOS

    idempotent_apply(pp)
  end
end
