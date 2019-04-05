class storage (
    Boolean $cifs_enabled           = $storage::params::cifs_enabled,
    Boolean $svc_enabled            = $storage::params::svc_enabled,
    Boolean $ssh_enabled            = $storage::params::ssh_enabled,
    Boolean $pcmk_enabled           = $storage::params::pcmk_enabled,
    Boolean $nfs_enabled            = $storage::params::nfs_enabled, 
    Boolean $gpfs_enabled           = $storage::params::gpfs_enabled,
    Boolean $gpfs_ces_enabled       = false,
    String $nfs_haaddr              = '',
    String $ctdb_haaddr             = '',
    Optional[Integer] $gpfs_oom_adj = undef,
) inherits storage::params {

    contain storage::install
    contain storage::config

    include cerit::passwd

    if $cifs_enabled {
        contain storage::cifs::init
    } elsif $pcmk_enabled {
      storage::pcmk::resource{'CIFS':
        present         => false,
        primitive_class => 'systemd',
        primitive_type  => 'ctdb',
        operations      => {
           'monitor'    => {'interval' => '120s', 'timeout' => '60s', 'start-delay' => '30', 'on-fail' => 'restart' },
           'start'      => {'interval' => '0', 'timeout' => '60s', 'on-fail' => 'restart' },
           'stop'       => {'interval' => '0', 'timeout' => '300s' },
        },
        clone           => true,
        ip              => 'nothing',
      }
    }

    if $ssh_enabled {
        contain storage::ssh::init
    }

    if $nfs_enabled {
        contain storage::nfs::init
    } elsif $pcmk_enabled {
      cs_order {'nfs_ip_order':
        ensure  => absent,
      }

      if $storage::ctdb_haddr == $storage::nfs_haddr {
        cs_colocation {'nfs_ip':
          primitives => ['NFS-gr', 'CIFSNFS-ip'],
          ensure     => absent,
        }
      } else {
        cs_colocation {'nfs_ip':
          primitives => ['NFS-gr', 'NFS-ip'],
          ensure     => absent,
        }
      }

      if ($storage::pcmk::config::groups != undef) and !(has_key($storage::pcmk::config::groups, 'NFS-gr')) {
        if $storage::nfs::config::svc_enabled {
          cs_group {'NFS-gr':
            primitives => ['NFS', 'SVCGSSD'],
            ensure     => absent,
          }
        } else {
          cs_group {'NFS-gr':
            primitives => ['NFS'],
            ensure     => absent,
          }
        }
      }

      cs_primitive {'SVCGSSD':
        ensure          => absent,
        primitive_class => 'systemd',
        primitive_type  => 'rpc-svcgssd',
      }

      storage::pcmk::resource {'NFS':
        present         => false,
        primitive_class => 'ocf',
        primitive_type  => 'nfsserver',
        provider        => 'heartbeat',
        operations      => {
          'monitor'     => {'interval' => '120s', 'timeout' => '60s', 'start-delay' => '30', 'on-fail' => 'restart' },
          'start'       => {'interval' => '0', 'timeout' => '300s', 'on-fail' => 'restart' },
          'stop'        => {'interval' => '0', 'timeout' => '600s' }, },
        ip              => 'nothing',
      }
    }

    if $pcmk_enabled {
        contain storage::pcmk::init
    }

    if $gpfs_enabled {
        contain storage::gpfs
    }

    if $gpfs_ces_enabled {
        contain storage::gpfs::init
    }

    if ( ! $cifs_enabled ) and ( ! $nfs_enabled ) and ( $pcmk_enabled ) {
      storage::pcmk::resource{'CIFSNFS-ip':
        present         => false,
        primitive_class => 'ocf',
        primitive_type  => 'IPaddr2',
        provider        => 'heartbeat',
        operations      => {
          'monitor' => { 'interval' => '10s', 'timeout' => '30s', 'on-fail' => 'restart' },
          'start'   => { 'interval' => '0', 'timeout' => '60s', 'on-fail' => 'restart' },
        }
      }
    }
}
