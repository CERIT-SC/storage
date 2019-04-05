class storage::pcmk::config(
  String $clustername              = $::clusterfullname,
  String $authkey                  = '/opt/puppetlabs/puppet/ssl/cert.pem',
  String $ring_mode                = 'active',
  Array  $bindiface                = [],
  Boolean $stonithen               = $storage::params::pcmk_stonith_enabled,
  Boolean $secauth                 = true,
  Boolean $fence_enabled           = $storage::params::pcmk_fence_enabled,
  Optional[String] $ipmi_user      = undef,
  Optional[String] $ipmi_password  = undef,
  Integer $node_count              = undef,
  Optional[Hash] $primitives       = undef,
  Optional[Hash] $groups           = undef,
  Optional[Hash] $colocations      = undef,
  Optional[Hash] $orders           = undef,
) inherits storage::params {

  if $bindiface.size > 0 {
    $_bindaddr = $bindiface.map |$iface| {
      $facts['networking']['interfaces'][$iface]['ip']
    }
  } else {
    $_bindaddr = [$::ipaddress]
  }

  $_this_node = puppetdb_query("resources{type='Storage::Pcmk::Pcmknode' and title='$::fqdn'}").map |$resource| {
    {
      ip      => $resource['parameters']['ip'],
      version => $resource['parameters']['version'],
    }
  }

  if ($_this_node.size == 0) or ($_this_node[0]['version'] == undef) {
    @@storage::pcmk::pcmknode { "$::fqdn":
      ip      => $_bindaddr,
      tag     => "$::clusterfullname",
      version => 0,
    }
  } else {
    $_node_ips = puppetdb_query("resources{type='Storage::Pcmk::Pcmknode' and tag='${::clusterfullname}' order by certname asc}").map |$resource| {
      $resource['parameters']['ip']
    }

    $_node_versions = puppetdb_query("resources{type='Storage::Pcmk::Pcmknode' and tag='${::clusterfullname}' order by certname asc}").map |$resource| {
      $resource['parameters']['version']
    }

    $_node_names = puppetdb_query("resources{type='Storage::Pcmk::Pcmknode' and tag='${::clusterfullname}' order by certname asc}").map |$resource| {
      $resource['title']
    }

    $_max_ver = max(*$_node_versions)
    $_ver_count = count($_node_versions, $_max_ver)

    if $_bindaddr != $_this_node[0]['ip'] {
      @@storage::pcmk::pcmknode { "$::fqdn":
        ip      => $_bindaddr,
        tag     => "$::clusterfullname",
        version => $_max_ver+1,
      }
    } else {
      @@storage::pcmk::pcmknode { "$::fqdn":
        ip      => $_bindaddr,
        tag     => "$::clusterfullname",
        version => $_max_ver,
      }

      if ($_node_ips.size == $node_count) and ($_ver_count == $_node_versions.size) {
        class { 'corosync':
          set_votequorum       => true,
          quorum_members       => $_node_ips,
          quorum_members_names => $_node_names,
          unicast_addresses    => $_node_ips,
          cluster_name         => $clustername,
          bind_address         => undef,
          enable_secauth       => $secauth,
          authkey              => $authkey,
          rrp_mode             => $ring_mode,
        }

        if $fence_enabled and $facts['ipmi_ipaddress'] != undef {
         if $ipmi_user == undef or $ipmi_password == undef{
           fail("fence enabled and ipmi user or ipmi password not set")
         }
         cs_primitive {"fence_${facts['hostname']}_ipmi":
           primitive_class => 'stonith',
           primitive_type  => 'fence_ipmilan',
           parameters      => { 'ipaddr' => $facts['ipmi_ipaddress'], 'login' => $ipmi_user, 'passwd' => $ipmi_password,
                                'pcmk_host_list' => $_bindaddr[0], 'lanplus' => '1'}
         }
        } else {
         cs_primitive {"fence_${facts['hostname']}_ipmi":
           ensure          => absent,
           primitive_class => 'stonith',
           primitive_type  => 'fence_ipmilan',
         }
        }

        cs_property { 'stonith-enabled' :
          value   => "${stonithen}",
        }
      }
    }
  }
}
