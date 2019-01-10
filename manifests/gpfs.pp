class storage::gpfs {        
        if $storage::gpfs_oom_adj != undef {
                exec{'gpfs_oom_adj':
                   command => "/bin/bash -c \"pid=`pidof mmfsd` && echo \"${storage::gpfs_oom_adj}\" > /proc/\\\$pid/oom_score_adj\"",
                   onlyif  => "/bin/bash -c \"pid=`pidof mmfsd`; test -z \\\$pid && exit 1; [ x\`cat /proc/\\\$pid/oom_score_adj\` != x${storage::gpfs_oom_adj} ]\"",
                   path    => "/bin:/usr/bin:/sbin:/usr/sbin",
                }
        }
}
