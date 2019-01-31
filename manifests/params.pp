class storage::params {
    $cifs_enabled           = false
    $cifs_netbiosname       = 'UVT'
    $cifs_homedir_tmpl      = '/home/%U'
    $cifs_sharename         = 'home'
    $cifs_sharepath         = '/home/%U'
    $cifs_smb_conf          = '/etc/samba/smb.conf'
    $cifs_ctdb_nodes        = '/etc/ctdb/nodes'
    $cifs_ctdb_pub_add      = '/etc/ctdb/public_addresses'
    $cifs_ctdb_conf         = '/etc/ctdb/ctdbd.conf'
    $cifs_ctdb_lock_dir     = '/home'
    $cifs_ctdb_samba        = 'yes'
    $cifs_ctdb_winbind      = 'yes'
    $cifs_ctdb_debuglevel   = 'ERR'
    $cifs_ctdb_nrfiles      = 10000
    $cifs_smb_idmap_range   = '3000000-9000000'
    $cifs_smb_idmap_backend = undef

    $ssh_enabled            = false
    $ssh_chroot             = '/'

    $pcmk_enabled           = false
    $pcmk_stonith_enabled   = false
    $pcmk_fence_enabled     = false

    $nfs_enabled            = false
    $svc_enabled            = true
    $nfsd_count             = '64'
    $nfs_gssproxy           = ''
    $nfs_svcgssd            = '-n'
    case $osfamily {
       'Debian': {
           $nfs_conf = '/etc/default/nfs'
       }
       'RedHat': {
           $nfs_conf = '/etc/sysconfig/nfs'
       }
    }
    $nfs_idmap_cfg           = '/etc/idmapd.conf'
    $nfs_idmap_domain        = undef
    $nfs_idmap_realms        = ''
    $nfs_idmap_switch        = 'nsswitch'
    $nfs_idmap_service       = 'rpcidmapd'
  
    $nfs_rpcbind_cfg         = '/etc/sysconfig/rpcbind'
    $nfs_rpcbind_optname     = 'RPCBIND_ARGS'
    $nfs_rpcbind_optval      = '-h 127.0.0.1'

    $gpfs_enabled            = false


    $nfs_export_tmp_file     = '/var/tmp/gpfs_exports_nfs.cfg'
    $smb_export_tmp_file     = '/var/tmp/gpfs_exports_smb.cfg'
    $ces_user_authentication = 'mmuserauth service create --data-access-method file --type userdefined' 
 
    $chroot_libdir           = '/lib64'
    $chroot_devfiles         = ['null', 'zero']
    $chroot_etcfiles         = ['profile.d', 'bashrc', 'host.conf', 'hosts', 'issue', 'krb5.conf', 'nsswitch.conf', 'profile', 'protocols', 'resolv.conf', 'services', 'vimrc']
}
