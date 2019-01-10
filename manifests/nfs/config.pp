class storage::nfs::config(
   String $nfs_conf        = $storage::params::nfs_conf,
   String $nfscount        = $storage::params::nfsd_count,
   String $nfsgssproxy     = $storage::params::nfs_gssproxy,
   String $nfssvcgssd      = $storage::params::nfs_svcgssd,
   String $infodir         = '',
   String $nfs_haaddr      = '',
   String $exports         = '',
   Optional[String] $idmap_domain    = $storage::params::nfs_idmap_domain,
   Optional[String] $idmap_realms    = $storage::params::nfs_idmap_realms,
   Optional[String] $idmap_switch    = $storage::params::nfs_idmap_switch,
   Optional[String] $idmap_cfg       = $storage::params::nfs_idmap_cfg,
   String $rpcbind_cfg     = $storage::params::nfs_rpcbind_cfg,
   String $rpcbind_optname = $storage::params::nfs_rpcbind_optname,
   String $rpcbind_optval  = $storage::params::nfs_rpcbind_optval, 
   Boolean $svc_enabled    = $storage::params::svc_enabled,
) inherits storage::params {

   file_line {'RPCNFSDARGS':
       path   => $nfs_conf,
       line   => "RPCNFSDARGS=\"${nfscount}\"",
       match  => 'RPCNFSDARGS',
    }
    
    file_line {'GSS_USE_PROXY':
       path   => $nfs_conf,
       line   => "GSS_USE_PROXY=\"${nfsgssproxy}\"",
       match  => 'GSS_USE_PROXY',
    }

    file_line {'RPCSVCGSSDARGS':
       path   => $nfs_conf,
       line   => "RPCSVCGSSDARGS=\"${nfssvcgssd}\"",
       match  => 'RPCSVCGSSDARGS',
    }

    service {'gssproxy':
       ensure => 'stopped',
       enable => 'mask',
    }

    augeas { $rpcbind_cfg:
      incl    => $rpcbind_cfg,
      lens    => 'Shellvars.lns', 
      context => "/files/${rpcbind_cfg}",
      changes => "set $rpcbind_optname  \"'$rpcbind_optval'\"",
    } ~> service{'rpcbind':}

    if $exports != '' {
       file{'/etc/exports':
          ensure  => present,
          content => "${exports}\n",
       } ~> exec{'reloadnfs':
              command     => '/usr/sbin/exportfs -ra',
              refreshonly => true,
       }
    }

    if $idmap_cfg != undef {
      augeas { $idmap_cfg:
        context => "/files/$idmap_cfg",
        lens    => 'Puppet.lns',
        incl    => $idmap_cfg,
        changes => ["set General/Domain $idmap_domain", "set General/Local-Realms $idmap_realms", "set Translation/Method $idmap_switch"],
      } ~> service{'rpcidmapd':}
    }
}
