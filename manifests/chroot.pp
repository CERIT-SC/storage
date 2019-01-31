class storage::chroot (
  Optional[String] $chroot_base     = undef,
  Optional[Hash]   $chroot_dirs     = undef,
  Optional[Hash]   $chroot_files    = undef,
  String           $chroot_libdir   = $storage::params::chroot_libdir,
  Array            $chroot_devfiles = $storage::params::chroot_devfiles,
  Array            $chroot_etcfiles = $storage::params::chroot_etcfiles,
) inherits storage::params {

  if $chroot_base != undef {
     $chroot_etcfiles.each |$_file| {
       if $_file !~ /\.\./ {
         exec { "cp_etc_${_file}":
           command => "cp -a /etc/${_file} ${chroot_base}/etc/",
           path    => ['/bin', '/usr/bin', '/sbin', '/usr/sbin'],
           unless  => "test -e ${chroot_base}/etc/${_file}",
         }
       } else {
         fail("Etc file {$_file} contains ..")          
       }
     }

     $chroot_dirs.map |$_dir, $_mode| {
       if $_dir !~ /\.\./ {
         if $_mode =~ /^[0-9]*$/ {
           file {"${chroot_base}/${_dir}":
             ensure => directory,
             mode   => $_mode,
           }
         } else {
           file {"${chroot_base}/${_dir}":
             path   => "${chroot_base}/${_dir}",
             ensure => link,
             target => $_mode,
           }
         }
       } else {
         fail("${_dir} contains .. as subpath")
       }
     }

     if $chroot_files.keys.size > 0 {
       exec { 'cp_loaders64':
         command => "cp -a /lib64/ld-* ${chroot_base}/${chroot_libdir}/",
         path    => ['/bin', '/usr/bin', '/sbin', '/usr/sbin'],
         unless  => "ls ${chroot_base}/${chroot_libdir}/ld-* &> /dev/null",
       }
    
       # these are dynamic loaded
       exec { 'cp_libnss':
         command => "cp -a /lib64/libnss* ${chroot_base}/${chroot_libdir}/",
         path    => ['/bin', '/usr/bin', '/sbin', '/usr/sbin'],
         unless  => "ls ${chroot_base}/${chroot_libdir}/libnss* &> /dev/null",
       }
  
       $chroot_devfiles.each |$_file| {
         if $_file !~ /\.\./ {
           exec { "cp_dev_${_file}":
             command => "cp -a /dev/${_file} ${chroot_base}/dev/",
             path    => ['/bin', '/usr/bin', '/sbin', '/usr/sbin'],
             unless  => "test -e  ${chroot_base}/dev/${_file}",
           }
         } else {
           fail("Dev file {$_file} contains ..")
         }
       } 
     }

     $chroot_files.map |$_file, $_target| {
       if $_target !~ /\.\./ {
         $_basename = regsubst($_file, '^.*\/', '')
         exec { "cp_${_file}":
           command => "cp ${_file} ${chroot_base}/${_target}",
           path    => ['/bin', '/usr/bin', '/sbin', '/usr/sbin'],
           unless  => "test -f ${chroot_base}/${_target}/$_basename",
         } ~> exec { "copy_libs_${_file}":
           command     => "/bin/bash -c \"for i in \\\$(ldd ${_file} | grep \\\"=>\\\" | grep \\\"/\\\" | sed -e 's/.*=> //' -e 's/ .*//'); do cp \\\$i ${chroot_base}${chroot_libdir}/; done\"",
           refreshonly => true,
         }
       }
     }
  }
}
