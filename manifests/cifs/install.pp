class storage::cifs::install {
    case $::operatingsystem {
       'Debian': {
           $packages = ['samba', 'ctdb', 'winbind']
        }
       'CentOS': {
           $packages = ['samba-winbind-clients', 'samba', 'ctdb', 'samba-winbind-modules']
       }
    }
    package{ $packages:
       ensure => $storage::cifs::config::samba_version
    }
}
