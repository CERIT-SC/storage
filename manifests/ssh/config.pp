class storage::ssh::config(
   Optional[String] $chroot        = $storage::params::ssh_chroot,
   Optional[String] $ha_ipaddress,
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
}
