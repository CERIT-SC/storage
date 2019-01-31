class storage::gpfs::ces (
  Optional[Array]       $nodes,
  Optional[Array]       $ces_ips,
  Optional[Boolean]     $enable_nfs,
  Optional[Hash]        $nfs_options,
  Optional[Hash]        $nfs_exports,
  Optional[Boolean]     $enable_smb,
  Optional[String]      $idmap_switch,
  String                $idmap_cfg               = $storage::params::nfs_idmap_cfg,
  Variant[String,Array] $idmap_service           = $storage::params::nfs_idmap_service,
  Optional[String]      $nfs_export_tmp_file     = $storage::params::nfs_export_tmp_file, 
  Optional[Hash]        $smb_global_options,
  Optional[Hash]        $smb_exports,
  Optional[String]      $smb_export_tmp_file     = $storage::params::smb_export_tmp_file,
  String                $user_authentication     = $storage::params::ces_user_authentication,
  Optional[String]      $ldap_password           = undef,
) inherits storage::params {

  if $nodes != undef and $nodes.size > 0 {
     if $nodes.size == 1 and $nodes[0] == 'all' {
       exec { 'add-all-ces-nodes':
         command => "mmchnode --ces-enable -N all",
         path    => ['/bin', '/usr/bin', '/sbin', '/usr/sbin', '/usr/lpp/mmfs/bin'],
         unless  => 'test `mmlscluster | grep -A32 "Daemon node name" | grep -v "^$" | tail -n +2 | wc -l` -eq `mmcesnode list | wc -l`',
       }
     } else {
       $nodes.each |$_node| {
          exec { "add-ces-node-${_node}":
            command => "mmchnode --ces-enable -N ${_node}",
            path    => ['/bin', '/usr/bin', '/sbin', '/usr/sbin', '/usr/lpp/mmfs/bin'],
            unless  => "mmcesnode list | grep -q ${_node}",
          }
       }
     }
  }

  if $ldap_password != undef {
    file { 'ldap_password':
      path => '/var/mmfs/ssl/keyServ/tmp/ldap',
      mode => '0600',
      content => "%fileauth:\npassword=${ldap_password}\n",
    }
  }

  exec { 'gpfs_ces_authentication':
    command => $ces_user_authentication, 
    path    => ['/bin', '/usr/bin', '/sbin', '/usr/sbin', '/usr/lpp/mmfs/bin'],
    unless  => 'mmuserauth service list | grep -q "FILE access configuration.*"',
  }
  
  if $enable_nfs {
     exec { "gpfs_ces_nfs":
       command => "mmces service enable NFS",
       path    => ['/bin', '/usr/bin', '/sbin', '/usr/sbin', '/usr/lpp/mmfs/bin'],
       unless  => "mmces service list | grep -q NFS",
     }

     $nfs_options.each |$_k, $_v| {
        storage::gpfs::config::nfs {"gpfs_nfs_config_${_k}":
          key   => $_k,
          value => $_v,
        }
     }

     $_nfs_export_cfg = $nfs_exports.map |String $_export, Hash $_defs| {
       $_clients_cfg = $_defs['clients'].map |Hash $_client| {
         $_params = {
           'access'  => $_client['access'],
           'client'  => $_client['client'],
           'sectype' => $_client['sec'],
           'squash'  => $_client['squash'],
         }
         epp('storage/ganesha.client.conf', $_params)
       }
       $_params = {
         'fsid'    => $_defs['fsid'],
         'export'  => $_export,
         'pseudo'  => $_defs['pseudo'],
         'clients' => join($_clients_cfg, "\n"),
       }
       epp('storage/ganesha.exports.conf', $_params)
     } 
     file {$nfs_export_tmp_file:
       ensure  => 'present',
       mode    => '0644',
       content => join($_nfs_export_cfg, "\n"),
     } ~> Exec['Reload-NFS-exports']

     exec {'Reload-NFS-exports':
       command     => "mmnfs export load ${nfs_export_tmp_file}",
       path        => ['/bin', '/usr/bin', '/sbin', '/usr/sbin', '/usr/lpp/mmfs/bin'],
       onlyif      => "test -s ${nfs_export_tmp_file}",
       refreshonly => true,
     }   
     if $idmap_switch != undef {
       augeas { $idmap_cfg: 
         context => "/files/${idmap_cfg}",
         lens    => 'Puppet.lns',
         incl    => $idmap_cfg,
         changes => [ "set Translation/Method ${idmap_switch}" ],
       } ~> service{$idmap_service:} ~> Exec['ccr_put_idmap.conf']

       exec {'ccr_put_idmap.conf':
         command     => "mmccr fput idmapd.conf ${idmap_cfg}",
         path        => ['/bin', '/usr/bin', '/sbin', '/usr/sbin', '/usr/lpp/mmfs/bin'],
         refreshonly => true,
       }
     }
  } else {
     exec { "gpfs_ces_nfs":
       command => "mmces service disable NFS",
       path    => ['/bin', '/usr/bin', '/sbin', '/usr/sbin', '/usr/lpp/mmfs/bin'],
       onlyif  => "mmces service list | grep -q NFS",
     }
  }
 
  if $enable_smb {
     exec { "gpfs_ces_smb":
       command => "mmces service enable SMB",
       path    => ['/bin', '/usr/bin', '/sbin', '/usr/sbin', '/usr/lpp/mmfs/bin'],
       unless  => "mmces service list | grep -q SMB",
     }

     exec { "gpfs_ces_start":
       command => "mmces service start smb",
       path    => ['/bin', '/usr/bin', '/sbin', '/usr/sbin', '/usr/lpp/mmfs/bin'],
       unless  => 'mmces service list | grep -q "SMB is running"',
     }
     
     if $smb_global_options != undef {
        $smb_global_options.each |$_k, $_v| {
           exec {"gpfs_ces_smb_${_k}":
             command => "net conf setparm global \"${_k}\" \"${_v}\"",
             path    => ['/bin', '/usr/bin', '/sbin', '/usr/sbin', '/usr/lpp/mmfs/bin'],
             unless  => "net conf list | grep -q '^.${_k}[ ]*=[ ]*${_v}'",
           }
        }
     }

     if $smb_exports != undef {
        $smb_exports.map |String $_export, Hash $_defs| {
          $_params = {
            export  => $_export,
            path    => $_defs['path'],
            comment => $_defs['comment'],
          }

          file {"$smb_export_tmp_file-$_export":
            ensure  => 'present',
            mode    => '0644',
            content => epp('storage/smb-share.conf', $_params),
          } ~> Exec["Reload-SMB-exports-${_export}"]

          exec {"Reload-SMB-exports-${_export}":
            command     => "net conf import ${smb_export_tmp_file}-${_export} ${_export}",
            path        => ['/bin', '/usr/bin', '/sbin', '/usr/sbin', '/usr/lpp/mmfs/bin'],
            onlyif      => "test -s ${smb_export_tmp_file}-${_export}",
            refreshonly => true,
          }
        }
     }
  } else {
     exec { "gpfs_ces_smb":
       command => "mmces service disable SMB",
       path    => ['/bin', '/usr/bin', '/sbin', '/usr/sbin', '/usr/lpp/mmfs/bin'],
       onlyif  => "mmces service list | grep -q SMB",
     }
  }

  if $ces_ips != undef and $ces_ips.size > 0 {
    $ces_ips.each |$_ip| {
       exec { "gpfs_ces_add_ip_${_ip}": 
          command => "mmces address add --ces-ip ${_ip}",
          path    => ['/bin', '/usr/bin', '/sbin', '/usr/sbin', '/usr/lpp/mmfs/bin'],
          unless  => "mmces address list | grep -q \"${_ip} \"",
       }
    }
  }
}
