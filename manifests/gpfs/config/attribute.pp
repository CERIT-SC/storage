define storage::gpfs::config::attribute (
  String $ensure = 'present',
  String $key,
  Optional[String] $value,
) {
  if $ensure == 'present' {
     exec { "mmchconfig-${key}":
       command => "mmchconfig \"${key}\"=\"$value\"",
       path    => ['/bin', '/usr/bin', '/sbin', '/usr/sbin', '/usr/lpp/mmfs/bin'],
       unless  => "mmlsconfig \"${key}\" | grep -q \"${key} ${value}\"",
     }
  } else {
     exec { "mmchconfig-${key}":
       command => "mmchconfig \"${key}\"=",
       path    => ['/bin', '/usr/bin', '/sbin', '/usr/sbin', '/usr/lpp/mmfs/bin'],
       unless  => "mmlsconfig \"${key}\" | grep -q \"${key}\"",
     }
  }
}
