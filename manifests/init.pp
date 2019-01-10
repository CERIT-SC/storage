class storage (
    Boolean $cifs_enabled           = $storage::params::cifs_enabled,
    Boolean $svc_enabled            = $storage::params::svc_enabled,
    Boolean $ssh_enabled            = $storage::params::ssh_enabled,
    Boolean $pcmk_enabled           = $storage::params::pcmk_enabled,
    Boolean $nfs_enabled            = $storage::params::nfs_enabled, 
    Boolean $gpfs_enabled           = $storage::params::gpfs_enabled,
    Boolean $gpfs_ces_enabled       = false,
    Optional[Integer] $gpfs_oom_adj = undef,
) inherits storage::params {

    contain storage::install
    contain storage::config

    include cerit::passwd

    if $cifs_enabled {
        contain storage::cifs::init
    }

    if $ssh_enabled {
        contain storage::ssh::init
    }

    if $nfs_enabled {
        contain storage::nfs::init
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
}
