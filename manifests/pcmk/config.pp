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
) inherits storage::params {
   
    if $bindiface.size > 0 {
      $_bindaddr = $bindiface.map |$iface| { $facts['networking']['interfaces'][$iface]['ip'] }
    } else {
      $_bindaddr = [$::ipaddress]
    }
    @@storage::pcmk::pcmknode{"pcmknode-$::fqdn":
       ip   => $_bindaddr,
       tag  => "$::clusterfullname",
    }

    Storage::Pcmk::Pcmknode <<| tag == "$::clusterfullname" |>> { }

    $_quorumnodes = puppetdb_query("resources{type='Storage::Pcmk::Pcmknode' and tag='$::clusterfullname' and certname='${trusted['certname']}'}").map |$resource| {
        $resource['parameters']['ip']
    }

    if ($_quorumnodes.size >= (0+$facts['clusternodenumber'])) and ($_bindaddr in $_quorumnodes) {
      class { 'corosync':
        set_votequorum    => true,
        quorum_members    => $_quorumnodes,
        unicast_addresses => $_quorumnodes,
        cluster_name      => $clustername,
        bind_address      => undef,
        enable_secauth    => $secauth,
        authkey           => $authkey,
        rrp_mode          => $ring_mode,
      }

      if $fence_enabled and $facts['ipmi_ipaddress'] != undef {
       if $ipmi_user == undef or $ipmi_password == undef{
         fail("fence enabled and ipmi user or ipmi password not set")
       }
       cs_primitive {"fence_${facts['hostname']}_ipmi":
         primitive_class => 'stonith',
         primitive_type  => 'fence_ipmilan',
         parameters      => { 'ipaddr' => $facts['ipmi_ipaddress'], 'login' => $ipmi_user, 'passwd' => $ipmi_password,
                              'pcmk_host_list' => $_bindaddr[0] }
       }
      }
  
      cs_property { 'stonith-enabled' :
        value   => "${stonithen}",
      }

      if $storage::ssh::config::ha_ipaddress != undef {
        if $storage::ssh::config::ha_ipaddress =~ /\// {
           $_net = split($storage::ssh::config::ha_ipaddress, '/')
           $_ssh_addr = $_net[0]
           $_ssh_mask = $_net[1]
        } else {
           $_ssh_addr = $storage::ssh::config::ha_ipaddress
           $_ssh_mask = '24'
        }
        cs_primitive {'SSH-ip':
           ensure          => present,
           primitive_class => 'ocf',
           primitive_type  => 'IPaddr2',
           provided_by     => 'heartbeat',
           parameters      => { 'ip' => $_ssh_addr, 'cidr_netmask' => $_ssh_mask },
           operations      => { 
                'monitor' => { 'interval' => '10s', 'timeout' => '30s', 'on-fail' => 'restart'},
                'start'   => { 'interval' => '0', 'timeout' => '60s', 'on-fail' => 'restart' }, 
           },
        }        
      }
  
      if $storage::cifs_enabled  {
        cs_primitive {'CIFS':
          primitive_class => 'systemd',
          primitive_type  => 'ctdb',
          operations      => {
             'monitor'    => {'interval' => '120s', 'timeout' => '60s', 'start-delay' => '30', 'on-fail' => 'restart' },
             'start'      => {'interval' => '0', 'timeout' => '60s', 'on-fail' => 'restart' },
             'stop'       => {'interval' => '0', 'timeout' => '300s' },
          }
        }
        cs_clone {'CIFS-clone':
           ensure    => present,
           primitive => 'CIFS',
           require   => Cs_primitive['CIFS'],
        }
        if $storage::cifs::config::ctdb_haaddr =~ /\// {
           $_net = split($storage::cifs::config::ctdb_haaddr, '/')
           $_cifs_addr = $_net[0]
           $_cifs_mask = $_net[1]
        } else {
           $_cifs_addr = $storage::cifs::config::ctdb_haaddr
           $_cifs_mask = '24'
        }
        cs_primitive {'CIFS-ip':
           ensure          => present,
           primitive_class => 'ocf',
           primitive_type  => 'IPaddr2',
           provided_by     => 'heartbeat',
           parameters      => { 'ip' => $_cifs_addr, 'cidr_netmask' => $_cifs_mask },
           operations      => { 
                'monitor' => { 'interval' => '10s', 'timeout' => '30s', 'on-fail' => 'restart'},
                'start'   => { 'interval' => '0', 'timeout' => '60s', 'on-fail' => 'restart' }, 
           },
           require         => Cs_clone['CIFS-clone'],
        }
        cs_order {'CIFS-order':
           first   => 'CIFS-clone',
           second  => 'CIFS-ip',
           kind    => 'Mandatory',
           require => Cs_primitive['CIFS-ip'],
        }
      }
  
      if $storage::nfs_enabled {
        file {$storage::nfs::config::infodir:
           ensure   => directory,
        }        
        cs_primitive {'NFS':
           ensure          => present,
           primitive_class => 'ocf',
           primitive_type  => 'nfsserver',
           provided_by     => 'heartbeat',
           parameters      => { 'nfs_ip'             => split($storage::nfs::config::nfs_haaddr, '/')[0],
                                'nfs_shared_infodir' => $storage::nfs::config::infodir, 
                                'nfsd_args'          => $storage::nfs::config::nfscount, },
           operations      => {
             'monitor'     => {'interval' => '120s', 'timeout' => '60s', 'start-delay' => '30', 'on-fail' => 'restart' },
             'start'       => {'interval' => '0', 'timeout' => '300s', 'on-fail' => 'restart' },
             'stop'        => {'interval' => '0', 'timeout' => '600s' }, },
           require         => File[$storage::nfs::config::infodir],
        }
        if $storage::nfs::config::svc_enabled {
           cs_primitive {'SVCGSSD':
              ensure          => present,
              primitive_class => 'systemd',
              primitive_type  => 'rpc-svcgssd',
              operations      => {
                'monitor'     => {'interval' => '60s', 'timeout' => '60s', 'start-delay' => '30', 'on-fail' => 'restart' },
                'start'       => {'interval' => '0', 'timeout' => '60s', 'on-fail' => 'restart' },
                'stop'        => {'interval' => '0', 'timeout' => '60s' }, },
              require         => Cs_primitive['NFS'],
           }
           cs_group {'NFS-gr':
              ensure          => present,
              primitives      => ['NFS', 'SVCGSSD'],
              require         => Cs_primitive['SVCGSSD'],
           }
        } else {
           cs_group {'NFS-gr':
              ensure     => present,
              primitives => ['NFS'],
           }
        }
  
        if $storage::cifs::config::ctdb_haaddr == $storage::nfs::config::nfs_haaddr {
           cs_colocation {'nfs_ip':
             primitives => [ 'NFS-gr', 'CIFS-ip' ],
             require    => Cs_primitive['CIFS-ip'],
           }
           #cs_order {'nfs_ip_order':
           #  first   => 'NFS-gr',
           #  second  => 'CIFS-ip',
           #  kind    => 'Mandatory',
           #  require => Cs_colocation['nfs_ip'],
           #}
        } else {
           if $storage::nfs::config::nfs_haaddr =~ /\// {
              $_net = split($storage::nfs::config::nfs_haaddr, '/')
              $_nfs_addr = $_net[0]
              $_nfs_mask = $_net[1]
           } else {
              $_nfs_addr = $storage::nfs::config::nfs_haaddr
              $_nfs_mask = '24'
           }
           cs_primitive {'NFS-ip':
             ensure          => present,
             primitive_class => 'ocf',
             primitive_type  => 'IPaddr2',
             provided_by     => 'heartbeat',
             parameters      => { 'ip' => $_nfs_addr, 'cidr_netmask' => $_nfs_mask },
             operations      => { 'monitor' => { 'interval' => '10s' } },
             require         => Cs_group['NFS-gr'],
           }
           cs_colocation {'nfs_ip':
             primitives => [ 'NFS-gr', 'NFS-ip' ],
             require    => Cs_primitive['NFS-ip'],
           }
           cs_order {'nfs_ip_order':
             first   => 'NFS-gr',
             second  => 'NFS-ip',
             kind    => 'Mandatory',
             require => Cs_colocation['nfs_ip'],
           }
        }
      }
    }
}
