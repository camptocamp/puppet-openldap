require 'base64'
#
# @summary
#         Returns the openldap password hash from the clear text password.
#
#
Puppet::Functions.create_function(:openldap_password) do
  # @param secret
  #   The secret to be hashed.
  #
  # @param scheme
  #   The optional scheme to use (defaults to SSHA).
  #
  # @return [String]
  #   The hashed secret.
  #
  dispatch :generate_password do
    required_param 'String', :secret
    optional_param 'Enum["CRYPT","MD5","SMD5","SSHA","SHA"]', :scheme

    return_type 'String'
  end

  def generate_password(secret, scheme = 'SSHA')
    case scheme[%r{([A-Z,0-9]+)}, 1]
    when 'CRYPT'
      salt = call_function(:fqdn_rand_string, 2)
      password = '{CRYPT}' + secret.crypt(salt)
    when 'MD5'
      password = '{MD5}' + Digest::MD5.hexdigest(secret)
    when 'SMD5'
      salt = call_function(:fqdn_rand_string, 8)
      md5_hash_with_salt = "#{Digest::MD5.digest(secret + salt)}#{salt}"
      password = '{SMD5}' + [md5_hash_with_salt].pack('m').delete("\n")
    when 'SSHA'
      salt = call_function(:fqdn_rand_string, 8)
      password = '{SSHA}' + Base64.encode64("#{Digest::SHA1.digest(secret + salt)}#{salt}").chomp
    when 'SHA'
      password = '{SHA}' + Digest::SHA1.hexdigest(secret)
    else
      raise(Puppet::ParseError, "openldap_password(): Unrecognized scheme #{scheme}")
    end

    password
  end
end
