require 'time'
require File.expand_path(File.join(File.dirname(__FILE__), %w[.. openldap]))

# rubocop:disable Style/VariableName
# rubocop:disable Style/MethodName
# rubocop:disable Lint/AssignmentInCondition
# rubocop:disable Style/IfInsideElse
Puppet::Type.
  type(:openldap_schema).
  provide(:olc, parent: Puppet::Provider::Openldap) do

  # TODO: Use ruby bindings (can't find one that support IPC)

  defaultfor osfamily: [:debian, :freebsd, :redhat, :suse]

  mk_resource_methods

  def self.instances
    schemas = []
    slapcat('(objectClass=olcSchemaConfig)').split("\n\n").each do |paragraph|
      schema = { 'name' => nil, 'index' => nil, 'date' => nil }
      paragraph.split("\n").each do |line|
        case line
        when %r{^cn: \{(\d+)\}(\S+)}
          schema['name'] = Regexp.last_match(2).to_s
          schema['index'] = Regexp.last_match(1).to_s
        when %r{^modifyTimestamp: (\S+)}
          schema['date'] = Time.strptime(Regexp.last_match(1).to_s, '%Y%m%d%H%M%S%Z')
        end
      end

      schemas.push(schema) unless schema['name'].nil?
    end
    schemas.map do |schema|
      new(
        ensure: :present,
        index: schema['index'],
        name: schema['name'],
        date: schema['date']
      )
    end
  end

  def self.schemaToLdif(schema, name)
    ldif = [
      "dn: cn=#{name},cn=schema,cn=config",
      'objectClass: olcSchemaConfig',
      "cn: #{name}",
    ]
    schema.split("\n").each do |line|
      case line
      when %r{^\s*#} # Comments are ok
        ldif.push(line)
      when %r{^$} # Replace empty lines with comment
        ldif.push('#')
      when %r{^objectidentifier(.*)$}i # Rewrite tags
        ldif.push("olcObjectIdentifier:#{Regexp.last_match(1)}")
      when %r{^attributetype(.*)$}i
        ldif.push("olcAttributeTypes:#{Regexp.last_match(1)}")
      when %r{^objectclass(.*)$}i
        ldif.push("olcObjectClasses:#{Regexp.last_match(1)}")
      when %r{^\s+(.*)} # Rewrite continuation whitespace
        ldif.push("  #{Regexp.last_match(1)}") # One space to indicate continuation, plus one for spacing between words
      else
        raise Puppet::Error, "Failed to parse schema line in schemaToLdif: '#{line}'"
      end
    end
    ldif.join("\n")
  end

  def self.schemaToLdifReplace(schema, name)
    ldif = [
      "dn: cn=#{name},cn=schema,cn=config",
      'changetype: modify',
    ]
    objId = []
    attrType = []
    objClass = []

    current = nil

    schema.split("\n").each do |line|
      case line
      when %r{^\s*#}
        next
      when %r{^$}
        next
      when %r{^objectidentifier(.*)$}i
        current = objId
        current.push("olcObjectIdentifier:#{Regexp.last_match(1)}")
      when %r{^attributetype(.*)$}i
        current = attrType
        current.push("olcAttributeTypes:#{Regexp.last_match(1)}")
      when %r{^objectclass(.*)$}i
        current = objClass
        current.push("olcObjectClasses:#{Regexp.last_match(1)}")
      when %r{^\s+(.*)}
        current.push("  #{Regexp.last_match(1)}") unless current.nil?
      else
        raise Puppet::Error, "Failed to parse schema line in schemaToLdifReplace: '#{line}'"
      end
    end

    unless objId.empty?
      ldif.push('replace: olcObjectIdentifier')
      ldif.push(*objId)
      ldif.push('-')
    end

    ldif.push('replace: olcAttributeTypes')
    ldif.push(*attrType)
    ldif.push('-')

    ldif.push('replace: olcObjectClasses')
    ldif.push(*objClass)
    ldif.push('-')

    ldif.join("\n")
  end

  def self.ldifReplace(ldif, name)
    new_ldif = [
      "dn: cn=#{name},cn=schema,cn=config",
      'changetype: modify',
    ]
    objId = []
    attrType = []
    objClass = []

    current = nil

    ldif.split("\n").each do |line|
      case line
      when %r{^\s*#}
        next
      when %r{^$}
        next
      when %r{^dn:}i
        next
      when %r{^cn:}i
        next
      when %r{objectClass:}i
        next
      when %r{^olcObjectIdentifier:\s+(.*)$}i
        current = objId
        current.push("olcObjectIdentifier:#{Regexp.last_match(1)}")
      when %r{^olcAttributeTypes:\s+(.*)$}i
        current = attrType
        current.push("olcAttributeTypes:#{Regexp.last_match(1)}")
      when %r{^olcObjectClasses:\s+(.*)$}i
        current = objClass
        current.push("olcObjectClasses:#{Regexp.last_match(1)}")
      when %r{^\s+(.*)}
        current.push("  #{Regexp.last_match(1)}") unless current.nil?
      else
        raise Puppet::Error, "Failed to parse LDIF line in ldifReplace: '#{line}'"
      end
    end

    unless objId.empty?
      new_ldif.push('replace: olcObjectIdentifier')
      new_ldif.push(*objId)
      new_ldif.push('-')
    end

    new_ldif.push('replace: olcAttributeTypes')
    new_ldif.push(*attrType)
    new_ldif.push('-')

    new_ldif.push('replace: olcObjectClasses')
    new_ldif.push(*objClass)
    new_ldif.push('-')

    new_ldif.join("\n")
  end

  def self.prefetch(resources)
    existing = instances
    resources.keys.each do |name|
      if provider = existing.find { |r| r.name == name }
        resources[name].provider = provider
      end
    end
  end

  def create
    t = Tempfile.new('openldap_schemas_ldif')

    begin
      schema = File.read(resource[:path])
      file_extention = File.extname(resource[:path])
      t << if file_extention == '.schema'
             if @property_hash[:ensure] == :present
               self.class.schemaToLdifReplace(schema, "{#{@property_hash[:index]}}#{@property_hash[:name]}")
             else
               self.class.schemaToLdif(schema, resource[:name])
             end
           else
             if @property_hash[:ensure] == :present
               self.class.ldifReplace(schema, "{#{@property_hash[:index]}}#{@property_hash[:name]}")
             else
               schema
             end
           end
      t.close
      ldapadd(t.path)
    rescue StandardError => e
      raise Puppet::Error, "LDIF content:\n#{IO.read t.path}\nError message: #{e.message}"
    end
    @property_hash[:ensure] = :present
  end

  def exists?
    if resource[:path] && File.file?(resource[:path])
      Puppet.debug("#{@property_hash[:name]} date: #{@property_hash[:date]}")
      Puppet.debug("#{@property_hash[:name]} mtime: #{File.mtime(resource[:path])}")
      timeshift = File.mtime(resource[:path]) - (@property_hash[:date] || 0)
      Puppet.debug("#{@property_hash[:name]} timeshift: #{timeshift}")
      @property_hash[:ensure] == :present && timeshift.to_i <= 0
    else
      @property_hash[:ensure] == :present
    end
  end

  def destroy
    raise Puppet::Error, 'Removing schemas is not supported by this provider. Slapd needs to be stopped and the schema must be removed manually.'
  end
end
