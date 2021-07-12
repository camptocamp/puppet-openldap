OpenLDAP
========

[![Puppet Forge Version](http://img.shields.io/puppetforge/v/camptocamp/openldap.svg)](https://forge.puppetlabs.com/camptocamp/openldap)
[![Puppet Forge Downloads](http://img.shields.io/puppetforge/dt/camptocamp/openldap.svg)](https://forge.puppetlabs.com/camptocamp/openldap)
[![Build Status](https://img.shields.io/travis/camptocamp/puppet-openldap/master.svg)](https://travis-ci.org/camptocamp/puppet-openldap)
[![Puppet Forge Endorsement](https://img.shields.io/puppetforge/e/camptocamp/openldap.svg)](https://forge.puppetlabs.com/camptocamp/openldap)
[![Donated by Camptocamp](https://img.shields.io/badge/donated%20by-camptocamp-fb7047.svg)](#transfer-notice)

Overview
--------

The openldap module allows you to easily manage OpenLDAP with Puppet.
By default it will use OLC (cn=config).

Features supported
------------------

Object      | olc (slapd.d) 
------------|--------------
global_conf | Y             
database    | Y             
module      | Y             
overlay     | Y             
access      | Y             
index       | Y             
schema      | Y             

Usage
-----

### Configuring the client

```puppet
class { 'openldap::client': }
```

For a more customized configuration:

```puppet
class { 'openldap::client':
  base       => 'dc=example,dc=com',
  uri        => ['ldap://ldap.example.com', 'ldap://ldap-master.example.com:666'],
  tls_cacert => '/etc/ssl/certs/ca-certificates.crt',
}
```

### Configuring the server

```puppet
class { 'openldap::server': }
openldap::server::database { 'dc=foo,dc=example.com':
  ensure => present,
}
```

For a more customized configuration:

```puppet
class { 'openldap::server':
  ldaps_ifs => ['/'],
  ssl_cert  => '/etc/ldap/ssl/slapd.pem',
  ssl_key   => '/etc/ldap/ssl/slapd.key',
}
```

If you need multiple databases:

```puppet
class { 'openldap::server':
  databases => {
    'dc=foo,dc=example,dc=com' => {
      directory => '/var/lib/ldap/foo',
    },
    'dc=bar,dc=example,dc=com' => {
      directory => '/var/lib/ldap/bar',
    },
  },
}
```

Configuring a global parameter:

```puppet
openldap::server::globalconf { 'security':
  ensure => present,
  value  => 'tls=128',
}
```

Configuring multiple olc serverIDs for multiple master or mirror mode

```puppet
openldap::server::globalconf { 'ServerID':
  ensure  => present,
  value   => { 'ServerID' => [ '1 ldap://master1.example.com', '2 ldap://master2.example.com' ] }
} 
```

Configuring security for global

```puppet
openldap::server::globalconf { 'Security':
  ensure  => present,
	value   => { 'Security' => [ 'simple_bind=128', 'ssf=128', 'tls=0' ] } 
```

### Configuring a database

```puppet
openldap::server::database { 'dc=example,dc=com':
  directory => '/var/lib/ldap',
  rootdn    => 'cn=admin,dc=example,dc=com',
  rootpw    => 'secret',
}
```

`rootpw` will be automatically converted to a SSHA hash with random salt.

Support SHA-2 password
```puppet
openldap::server::database { 'dc=example,dc=com':
  directory => '/var/lib/ldap',
  rootdn    => 'cn=admin,dc=example,dc=com',
  rootpw    => '{SHA384}QZdaK3FnibbilSPbthnf3cO8lBWsRyM9i1MZTUFP21RdBSLSNFgYc2eFFzJG/amX',
}
```

### Configuring modules

```puppet
openldap::server::module { 'memberof':
  ensure => present,
}
```

### Configuring overlays

```puppet
openldap::server::overlay { 'memberof on dc=example,dc=com':
  ensure => present,
}
```

### Configuring ACPs/ACLs

[Documentation](http://www.openldap.org/devel/admin/slapdconf2.html) about olcAcces state the following spec:
> 5.2.5.2. olcAccess: to &lt;what&gt; [ by &lt;who&gt; [&lt;accesslevel&gt;] [&lt;control&gt;] ]+

So we supports natively this way of writing in the title:
```puppet
openldap::server::access { 'to attrs=userPassword,shadowLastChange by dn="cn=admin,dc=example,dc=com" write by anonymous auth' :
  suffix   => 'dc=example,dc=com',
}
```

Also is supported writing priority in title like olcAccess in ldap
```puppet
openldap::server::access { '{0}to attrs=userPassword,shadowLastChange by dn="cn=admin,dc=example,dc=com" write by anonymous auth' :
  suffix   => 'dc=example,dc=com',
}
```

As a single line with suffix:
```puppet
openldap::server::access { '{0}to attrs=userPassword,shadowLastChange by dn="cn=admin,dc=example,dc=com" write by anonymous auth on dc=example,dc=com' : }
```

Defining priority and suffix in the title:
```puppet
openldap::server::access { '0 on dc=example,dc=com':
  what     => 'attrs=userPassword,shadowLastChange',
  access   => [
    'by dn="cn=admin,dc=example,dc=com" write',
    'by anonymous auth',
    'by self write',
    'by * none',
  ],
}
```

from the openldap [documentation](http://www.openldap.org/doc/admin24/slapdconf2.html)
> The frontend is a special database that is used to hold database-level 
options that should be applied to all the other databases. Subsequent database
definitions may also override some frontend settings.

So use the suffix 'frontend' for this special database


```puppet
openldap::server::access { '0 on frontend' :
  what   => '*',
  access => [
    'by dn.exact=gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth manage',
    'by * break',
  ],
}
```


#### Note #1:
The chaining arrows `->` are importants if you want to order your entries.
Openldap put the entry as the last available position.
So if you got in your ldap:
```
 olcAccess: {0}to ...
 olcAccess: {1}to ...
 olcAccess: {2}to ...
```

  Even if you set the parameter `position => '4'`, the next entry will be set as

```
 olcAccess: {3}to ...
```

#### Note #2:
  The parameter `islast` is used for purging remaining entries. Only one `islast` is allowed per suffix. If you got in your ldap:
```
 olcAccess: {0}to ...
 olcAccess: {1}to ...
 olcAccess: {2}to ...
 olcAccess: {3}to ...
```

And set :
```puppet
openldap::server::access { '1 on dc=example,dc=com':
  what   => ...,
  access => [...],
  islast => true,
}
```

entries 2 and 3 will get deleted.

#### Call your acl from a hash:
The class `openldap::server::access_wrapper` was designed to simplify creating ACL.
If you have multiple `what` (`to *` in this example), you can order them by adding number to it.

```puppet
$example_acl = {
  '1 to *' => [
    'by dn.exact=gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth manage',
    'by dn.exact=cn=admin,dc=example,dc=com write',
    'by dn.exact=cn=replicator,dc=example,dc=com read',
    'by * break',
  ],
  'to attrs=userPassword,shadowLastChange' => [
    'by dn="cn=admin,dc=example,dc=com" write',
    'by self write',
    'by anonymous auth',
  ],
  '2 to *' => [
    'by self read',
  ],
}

openldap::server::access_wrapper { 'dc=example,dc=com' :
  acl => $example_acl,
}
```

### Configuring Schemas
```puppet
openldap::server::schema { 'samba':
  ensure  => present,
  path    => '/etc/ldap/schema/samba.schema',
  require => Openldap::Server::Schema["inetorgperson"],
}

openldap::server::schema { 'nis':
  ensure  => present,
  path    => '/etc/ldap/schema/nis.ldif',
  require => Openldap::Server::Schema["inetorgperson"],
}
```

### Configuring Rewrite-overlay
```puppet
openldap::server::database { 'relay':
  ensure  => present,
  backend => 'relay',
  suffix  => 'o=example',
  relay   => 'dc=example,dc=com',
}->

openldap::server::overlay { "rwm on relay":
  ensure  => present,
  suffix  => 'cn=config',
  overlay => 'rwm',
  options => {
    'olcRwmRewrite' => [
      'rwm-rewriteEngine "on"',
      'rwm-suffixmassage , "dc=example,dc=com"]',
  },
}
```


## Transfer Notice

This plugin was originally authored by [Camptocamp](http://www.camptocamp.com).
The maintainer preferred that Puppet Community take ownership of the module for future improvement and maintenance.
Existing pull requests and issues were transferred over, please fork and continue to contribute here instead of Camptocamp.

Previously: https://github.com/camptocamp/puppet-openldap
