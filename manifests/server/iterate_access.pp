#  This is a 'private' class used by openldap::server::access_wrapper
define openldap::server::iterate_access (
  $hash,
) {
  # Call individual openldap::server::access
  $position = $hash[$name]['position']
  $what     = $hash[$name]['what']
  $access   = $hash[$name]['access']
  $suffix   = $hash[$name]['suffix']

  $count    = count($hash)-1

  if ! is_array($access) {
    fail('$access variable must be an array')
  }

  if $position == 0 { # the first entry

    openldap::server::access { "${position} on ${suffix}" :
      what   => $what,
      access => $access,
    }
  } elsif $position == $count { #the last entry

    $previous_position = $position - 1
    openldap::server::access { "${position} on ${suffix}" :
      what    => $what,
      access  => $access,
      islast  => true,
      require => Openldap::Server::Access["${previous_position} on ${suffix}"],
    }
  } else {
    $previous_position = $position - 1
    openldap::server::access { "${position} on ${suffix}" :
      what    => $what,
      access  => $access,
      require => Openldap::Server::Access["${previous_position} on ${suffix}"],
    }
  }
}
