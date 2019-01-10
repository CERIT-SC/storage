class storage::cifs::install {
    case $::operatingsystem {
       'Debian': {
           $packages = ['samba', 'ctdb', 'winbind', 'libpam-script']
        }
       'CentOS': {
           $packages = ['samba-winbind-clients', 'samba', 'ctdb', 'samba-winbind-modules', 'pam_script']
       }
    }
    package{ $packages:
       ensure => latest
    }
}
