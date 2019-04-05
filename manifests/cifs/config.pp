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
    Optional[String] $bindiface     = '',
    String $workgroup               = $storage::params::cifs_workgroup,
    String $realm                   = $storage::params::cifs_realm,
    String $server_string           = $storage::params::cifs_server_string,
    String $security                = $storage::params::cifs_security,
    String $cifs_loglevel           = $storage::params::cifs_loglevel,
    String $logfile                 = $storage::params::cifs_logfile,
    Integer $logsize                = $storage::params::cifs_logsize,
    Boolean $enum_users             = $storage::params::cifs_enum_users,
    Boolean $enum_groups            = $storage::params::cifs_enum_groups,
    Integer $idmap_cache_time       = $storage::params::cifs_idmap_cache_time,
    Optional[String] $preexec       = $storage::params::cifs_preexec,
    String $samba_version           = $storage::params::cifs_samba_version,
) inherits storage::params {
    $params = {
       'netbios_name'     => $netbiosname,
       'homedir_tmpl'     => $homedir_tmpl,
       'sharename'        => $sharename,
       'sharepath'        => $sharepath,
       'trash'            => $trash,
       'custom_shares'    => $custom_shares,
       'idmap_range'      => $idmap_range,
       'idmap_backend'    => $idmap_backend,
       'workgroup'        => $workgroup,
       'realm'            => $realm,
       'server_string'    => $server_string,
       'security'         => $security,
       'loglevel'         => $cifs_loglevel,
       'logfile'          => $logfile,
       'logsize'          => $logsize,
       'enum_users'       => $enum_users,
       'enum_groups'      => $enum_groups,
       'idmap_cache_time' => $idmap_cache_time,
       'preexec'          => $preexec,
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

         file{'pam_ses_open':
            ensure => link,
            path   => '/etc/pam-script.d/pam_script_ses_open',
            target => '/usr/bin/true',
         }

         file{'pam_ses_close':
            ensure => link,
            path   => '/etc/pam-script.d/pam_script_ses_close',
            target => '/usr/bin/true',
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

    # pacemaker

    if $storage::pcmk_enabled {
      require storage::pcmk::config
      if $storage::ctdb_haaddr =~ /\// {
         $_net = split($storage::ctdb_haaddr, '/')
         $_cifs_addr = $_net[0]
         $_cifs_mask = $_net[1]
      } else {
         $_cifs_addr = $storage::ctdb_haaddr
         $_cifs_mask = '24'
      }

      if $storage::ctdb_haaddr == $storage::nfs_haaddr {
        storage::pcmk::resource{'CIFS':
          primitive_class => 'systemd',
          primitive_type  => 'ctdb',
          operations      => {
             'monitor'    => {'interval' => '120s', 'timeout' => '60s', 'start-delay' => '30', 'on-fail' => 'restart' },
             'start'      => {'interval' => '0', 'timeout' => '60s', 'on-fail' => 'restart' },
             'stop'       => {'interval' => '0', 'timeout' => '300s' },
          },
          clone           => true,
        }

        if ! defined(Storage::Pcmk::Resource['CIFSNFS-ip']) {
          storage::pcmk::resource{'CIFSNFS-ip':
            present         => true,
            primitive_class => 'ocf',
            primitive_type  => 'IPaddr2',
            provider        => 'heartbeat',
            parameters      => { 'ip' => $_cifs_addr, 'cidr_netmask' => $_cifs_mask },
            operations      => {
              'monitor' => { 'interval' => '10s', 'timeout' => '30s', 'on-fail' => 'restart' },
              'start'   => { 'interval' => '0', 'timeout' => '60s', 'on-fail' => 'restart' },
            },
            require         => Cs_primitive['CIFS'],
          }
        }
      } else {
        storage::pcmk::resource{'CIFS':
          primitive_class => 'systemd',
          primitive_type  => 'ctdb',
          operations      => {
             'monitor'    => {'interval' => '120s', 'timeout' => '60s', 'start-delay' => '30', 'on-fail' => 'restart' },
             'start'      => {'interval' => '0', 'timeout' => '60s', 'on-fail' => 'restart' },
             'stop'       => {'interval' => '0', 'timeout' => '300s' },
          },
          clone           => true,
          ip              => $_cifs_addr,
          netmask         => $_cifs_mask,
        }
      }
    }
}
