class storage::gpfs::install {

   case $facts['osfamily'] {
      'RedHat': {
         $_packages = [ 'libnfsidmap-mnsswitch' ]
      }
   }

   if $_packages != undef {
     package { $_packages:
        ensure => latest,
     }
   }
}
