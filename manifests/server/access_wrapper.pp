# == Define openldap::server::access_wrapper
#
# Generate access from a given hash.
#
# === Parameters
#
# [*suffix*]
#   Default: $name
#   Mandatory. The suffix to apply acls
#
# [*acl*]
#   Default:
#   Mandatory. Hash in the form { <what> => <access>, ... }
#
#   example:
#     $acl = {
#       'to *' => [
#         'by self write',
#         'by anonymous read',
#       ],
#     }
#
define openldap::server::access_wrapper (
  $acl,
  $suffix = $name,
) {
  # Parse ACL
$acl_yaml = inline_template('<%=
    position = -1
    @acl.map { |to,access|
      position = position + 1
      {
        "#{position} on #{@suffix}" => {
          "position" => position,
          "what"     => to[/.*\bto (.*)/,1],
          "access"   => access,
          "suffix"   => "#{@suffix}",
        }
      }
  }.flatten.reduce({}, :update).to_yaml
  %>')

  $hash = parseyaml($acl_yaml)
  $hash_keys = keys($hash)

  openldap::server::iterate_access { $hash_keys :
    hash => $hash,
  }
}
