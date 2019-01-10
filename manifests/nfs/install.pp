class storage::nfs::install {
    case $::operatingsystem {
       'Debian': {
           $packages = ['nfs-kernel-server']
        }
       'CentOS': {
           $packages = ['nfs-utils', 'libnfsidmap-mnsswitch']
       }
    }
    package{ $packages:
       ensure => latest
    }
}
