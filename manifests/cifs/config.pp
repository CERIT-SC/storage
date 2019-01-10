class storage::cifs::config (
    String $netbiosname             = $storage::params::cifs_netbiosname,
    String $homedir_tmpl            = $storage::params::cifs_homedir_tmpl,
    String $sharename               = $storage::params::cifs_sharename,
    String $sharepath               = $storage::params::cifs_sharepath,
    String $trash                   = '',
    String $custom_shares           = '',
    String $smb_conf                = $storage::params::cifs_smb_conf,
    String $ctdb_nodes              = $storage::params::cifs_ctdb_nodes,
    String $ctdb_pub_add            = $storage::params::cifs_ctdb_pub_add,
    String $ctdb_conf               = $storage::params::cifs_ctdb_conf,
    String $ctdb_lock_dir           = $storage::params::cifs_ctdb_lock_dir,
    String $ctdb_samba              = $storage::params::cifs_ctdb_samba,
    String $ctdb_winbind            = $storage::params::cifs_ctdb_winbind,
    String $ctdb_debuglevel         = $storage::params::cifs_ctdb_debuglevel,
    Integer $ctdb_nrfiles           = $storage::params::cifs_ctdb_nrfiles,
    String $idmap_range             = $storage::params::cifs_smb_idmap_range,
    Optional[String] $idmap_backend = $storage::params::cifs_smb_idmap_backend,
    String $ctdb_haaddr             = '',
    Optional[String] $bindiface     = '',
) inherits storage::params {
   
    $params = {
       'netbios_name'  => $netbiosname,
       'homedir_tmpl'  => $homedir_tmpl,
       'sharename'     => $sharename,
       'sharepath'     => $sharepath,
       'trash'         => $trash,
       'custom_shares' => $custom_shares,
       'idmap_range'   => $idmap_range,
       'idmap_backend' => $idmap_backend,
    }

    file {$smb_conf:
       ensure   => present,
       mode     => '0644',
       content  => epp('storage/smb.conf', $params),
    } ~> Exec['Reload-SMB']

    exec{'Reload-SMB':
       command     => 'service smb reload',
       refreshonly => true,
    }

    file {$ctdb_pub_add:
       ensure   => present,
       mode     => '0644',
       content  => '',
    }

    if $bindiface != undef and $bindiface != '' {
       $_ip = $facts['networking']['interfaces'][$bindiface]['ip']
    } else {
       $_ip = $facts['networking']['ip']
    }

    @@storage::cifs::ctdbnode{"ctdbnode-$::fqdn":
       ip   => $_ip,
       cfg  => $ctdb_nodes,
       tag  => "$::clusterfullname",
    }

    Storage::Cifs::Ctdbnode <<| tag == "$::clusterfullname" |>> { }

    concat {$ctdb_nodes:
       ensure   => present,
       mode     => '0644',
       owner    => 'root',
       group    => 'root',
    }

    file_line {'CTDB_NODES':
       path   => $ctdb_conf,
       line   => "CTDB_NODES=$ctdb_nodes",
       match  => 'CTDB_NODES',
    }
    file_line {'CTDB_DEBUGLEVEL':
       path   => $ctdb_conf,
       line   => "CTDB_DEBUGLEVEL=$ctdb_debuglevel",
       match  => 'CTDB_DEBUGLEVEL',
    }
    file_line {'CTDB_SAMBA':
       path   => $ctdb_conf,
       line   => "CTDB_MANAGES_SAMBA=$ctdb_samba",
       match  => 'CTDB_MANAGES_SAMBA',
    }

    file_line {'CTDB_WINBIND':
       path   => $ctdb_conf,
       line   => "CTDB_MANAGES_WINBIND=$ctdb_winbind",
       match  => 'CTDB_MANAGES_WINBIND',
    }

    file_line {'CTDB_ulimit':
       path   => $ctdb_conf,
       line   => "CTDB_MAX_OPEN_FILES=$ctdb_nrfiles",
       match  => 'CTDB_MAX_OPEN_FILES',
    }
    
    file_line {'CTDB_SCRIPT_TIMEOUT':
       path   => $ctdb_conf,
       line   => 'CTDB_SET_EventScriptTimeout=300',
       match  => 'CTDB_SET_EventScriptTimeout',
    }

    file{$ctdb_lock_dir:
       ensure => directory,
       mode   => '0755',
    }

    file_line {'CTDB_RECOVERYLOCK':
       path   => $ctdb_conf,
       line   => "CTDB_RECOVERY_LOCK=$ctdb_lock_dir/ctdb.lck",
       match  => 'CTDB_RECOVERY_LOCK',
    }

    case $osfamily {
       'RedHat': {
         exec {'authconfig-enablewinbind':
            command => 'authconfig --enablewinbind --enablewinbindauth --update',
            unless  => 'grep -F pam_winbind /etc/pam.d/password-auth',
            path    => '/bin:/usr/bin:/sbin/:/usr/sbin',
            require => Package['samba-winbind-modules'], 
         }

         pam {'pam_script':
            ensure    => present,
            service   => 'password-auth',
            type      => 'session',
            control   => 'required',
            module    => 'pam_script.so',
            arguments => 'dir=/etc/pam-script.d/',
            position  => 'before module pam_systemd.so',
         }

         pam {'password-auth':
            ensure    => absent,
            service   => 'samba',
            type      => 'session',
            module    => 'password-auth',
         }
            
         pam {'pam_limits':
            ensure    => present,
            service   => 'samba',
            type      => 'session',
            control   => 'required',
            module    => 'pam_limits.so',
         }
         pam {'pam_script_samba':
            ensure    => present,
            service   => 'samba',
            type      => 'session',
            control   => 'required',
            module    => 'pam_script.so',
            arguments => 'dir=/etc/pam-script.d/',
            position  => 'after module pam_limits.so',
         }
         pam {'pam_winbind':
            ensure    => present,
            service   => 'samba',
            type      => 'session',
            control   => 'optional',
            module    => 'pam_winbind.so',
            position  => 'after module pam_script.so.so',
         }
            
       }
       default: {
         fail("Unsupported OS: ${::operatingsystem}")
       }
    }

    if $facts['gpfs_acls'] != undef {
       $facts['gpfs_acls'].each |String $fs, String $acl| {
         if $fs in $sharepath {
            if $acl != 'all' {
               fail("Filesystem $fs does not have acls in ALL mode")
            }
         }
       }
    }
}
