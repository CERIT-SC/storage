class storage::nfs::config(
  String $nfs_conf               = $storage::params::nfs_conf,
  String $nfscount               = $storage::params::nfsd_count,
  String $nfsgssproxy            = $storage::params::nfs_gssproxy,
  String $nfssvcgssd             = $storage::params::nfs_svcgssd,
  String $infodir                = '',
  String $exports                = '',
  Optional[String] $idmap_domain = $storage::params::nfs_idmap_domain,
  Optional[String] $idmap_realms = $storage::params::nfs_idmap_realms,
  Optional[String] $idmap_switch = $storage::params::nfs_idmap_switch,
  Optional[String] $idmap_cfg    = $storage::params::nfs_idmap_cfg,
  String $rpcbind_cfg            = $storage::params::nfs_rpcbind_cfg,
  String $rpcbind_optname        = $storage::params::nfs_rpcbind_optname,
  String $rpcbind_optval         = $storage::params::nfs_rpcbind_optval,
  Boolean $svc_enabled           = $storage::params::svc_enabled,
  String $export_root            = '',
  String $export_root_clients    = '',
) inherits storage::params {
  $_exports_split=split($exports, '\n')

  class { '::nfs':
    server_enabled             => true,
    nfs_v4                     => true,
    nfs_v4_idmap_domain        => $idmap_domain,
    nfs_v4_export_root         => $export_root,
    nfs_v4_export_root_clients => $export_root_clients,
    server_package_ensure      => 'latest',
    defaults_file              => $nfs_conf,
    nfs_count                  => $nfscount,
    nfs_gssproxy               => $nfsgssproxy,
    nfs_svcgssd                => $nfssvcgssd,
    client_rpcbind_config      => $rpcbind_cfg,
    client_rpcbind_optname     => $rpcbind_optname,
    client_rpcbind_opts        => $rpcbind_optval,
    idmap_switch               => $idmap_switch,
  }

  $_exports_split.each |String $export| {
    $_export_data=split($export, ' ')
    nfs::server::export { "${_export_data[0]}":
      ensure  => 'present',
      bind    => 'nobind',
      clients => join($_export_data[1,-1], " "),
    }
  }

  # pacemaker

  if $storage::pcmk_enabled {
    require storage::pcmk::config

    file {$storage::nfs::config::infodir:
      ensure   => directory,
    }

    if $storage::nfs_haaddr =~ /\// {
      $_net = split($storage::nfs_haaddr, '/')
      $_nfs_addr = $_net[0]
      $_nfs_mask = $_net[1]
    } else {
      $_nfs_addr = $storage::nfs_haaddr
      $_nfs_mask = '24'
    }

    if $storage::ctdb_haaddr == $storage::nfs_haaddr {
      storage::pcmk::resource { 'NFS':
        primitive_class => 'ocf',
        primitive_type  => 'nfsserver',
        provider        => 'heartbeat',
        parameters      => { 'nfs_ip'             => split($storage::nfs_haaddr, '/')[0],
                             'nfs_shared_infodir' => $storage::nfs::config::infodir,
                             'nfsd_args'          => $storage::nfs::config::nfscount, },
        operations      => {
          'monitor' => {'interval' => '120s', 'timeout' => '60s', 'start-delay' => '30', 'on-fail' => 'restart' },
          'start'   => {'interval' => '0', 'timeout' => '300s', 'on-fail' => 'restart' },
          'stop'    => {'interval' => '0', 'timeout' => '600s' }, },
      }

      if ! defined(Storage::Pcmk::Resource['CIFSNFS-ip']) {
        storage::pcmk::resource{'CIFSNFS-ip':
          present         => true,
          primitive_class => 'ocf',
          primitive_type  => 'IPaddr2',
          provider        => 'heartbeat',
          parameters      => { 'ip' => $_nfs_addr, 'cidr_netmask' => $_nfs_mask },
          operations      => {
            'monitor' => { 'interval' => '10s', 'timeout' => '30s', 'on-fail' => 'restart' },
            'start'   => { 'interval' => '0', 'timeout' => '60s', 'on-fail' => 'restart' },
          },
          require         => Cs_primitive['NFS'],
        }
      }

      cs_colocation {'nfs_ip':
        primitives => [ 'NFS-gr', 'CIFSNFS-ip' ],
        require    => [Cs_primitive['CIFSNFS-ip'], Cs_group['NFS-gr']],
      }

      cs_order {'nfs_ip_order':
        first   => 'NFS-gr',
        second  => 'CIFSNFS-ip',
        kind    => 'Mandatory',
        require => Cs_colocation['nfs_ip'],
      }
    } else {
      storage::pcmk::resource { 'NFS':
        primitive_class => 'ocf',
        primitive_type  => 'nfsserver',
        provider        => 'heartbeat',
        parameters      => { 'nfs_ip'             => split($storage::nfs_haaddr, '/')[0],
                             'nfs_shared_infodir' => $storage::nfs::config::infodir,
                             'nfsd_args'          => $storage::nfs::config::nfscount, },
        operations      => {
          'monitor' => {'interval' => '120s', 'timeout' => '60s', 'start-delay' => '30', 'on-fail' => 'restart' },
          'start'   => {'interval' => '0', 'timeout' => '300s', 'on-fail' => 'restart' },
          'stop'    => {'interval' => '0', 'timeout' => '600s' }, },
        ip              => $_nfs_addr,
        netmask         => $_nfs_mask,
      }

      cs_colocation {'nfs_ip':
        primitives => [ 'NFS-gr', 'NFS-ip' ],
        require    => [Cs_primitive['NFS-ip'], Cs_group['NFS-gr']],
      }

      cs_order {'nfs_ip_order':
        first   => 'NFS-gr',
        second  => 'NFS-ip',
        kind    => 'Mandatory',
        require => Cs_colocation['nfs_ip'],
      }
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
      if ($storage::pcmk::config::groups == undef) or (! has_key($storage::pcmk::config::groups, 'NFS-gr')) {
        cs_group {'NFS-gr':
          ensure     => present,
          primitives => ['NFS', 'SVCGSSD'],
        }
      }
    } else {
      if ($storage::pcmk::config::groups == undef) or (! has_key($storage::pcmk::config::groups, 'NFS-gr')) {
        cs_group {'NFS-gr':
          ensure     => present,
          primitives => ['NFS'],
        }
      }
    }
  }
}
