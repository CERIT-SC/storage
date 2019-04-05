class storage::ssh::config(
   Optional[String] $chroot        = $storage::params::ssh_chroot,
   Optional[String] $ha_ipaddress  = undef,
) inherits storage::params {

  ssh::server::config::match {'MatchRoot':
    ensure    => 'present',
    condition => {'User' => 'root'},
    settings  => {'ChrootDirectory' => 'none', 
                  'X11Forwarding'   => 'yes'},
  }

  ssh::server::config {'DenyUsersAdmin':
    ensure   => 'admin',
    key      => 'DenyUsers/1',
  }

  ssh::server::config {'DenyUsersAdministrator':
    ensure   => 'administrator',
    key      => 'DenyUsers/2',
  }

  ssh::server::config {'sftp':
    ensure   => 'internal-sftp',
    key      => 'Subsystem/sftp',
  }

  ssh::server::config {'chroot':
    ensure   => $chroot,
    key      => 'ChrootDirectory',
  }

  if $storage::pcmk::enabled {
    if $ha_ipaddress != undef {
      if $ha_ipaddress =~ /\// {
         $_net = split($ha_ipaddress, '/')
         $_ssh_addr = $_net[0]
         $_ssh_mask = $_net[1]
      } else {
         $_ssh_addr = $ha_ipaddress
         $_ssh_mask = '24'
      }

      storage::pcmk::resource {'SSH-ip':
        present         => true,
        primitive_class => 'ocf',
        primitive_type  => 'IPaddr2',
        provider        => 'heartbeat',
        parameters      => { 'ip' => $_ssh_addr, 'cidr_netmask' => $_ssh_mask },
        operations      => {
          'monitor' => { 'interval' => '10s', 'timeout' => '30s', 'on-fail' => 'restart' },
          'start'   => { 'interval' => '0', 'timeout' => '60s', 'on-fail' => 'restart' },
        },
      }
    } else {
      storage::pcmk::resource {'SSH-ip':
        present         => false,
        primitive_class => 'ocf',
        primitive_type  => 'IPaddr2',
        provider        => 'heartbeat',
        operations      => {
          'monitor' => { 'interval' => '10s', 'timeout' => '30s', 'on-fail' => 'restart'},
          'start'   => { 'interval' => '0', 'timeout' => '60s', 'on-fail' => 'restart' },
        },
      }
    }
  }
}
