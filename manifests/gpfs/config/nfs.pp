define storage::gpfs::config::nfs (
  String $ensure = 'present',
  String $key,
  Optional[String] $value,
) {
  if $ensure == 'present' {
     ## HACK
     if $key == 'IDMAPD_DOMAIN' {
       $_test_key = 'DOMAIN'
     } else {
       $_test_key = $key
     }

     exec { "mmnfs-${key}":
       command => "mmnfs config change \"${key}\"=\"$value\"",
       path    => ['/bin', '/usr/bin', '/sbin', '/usr/sbin', '/usr/lpp/mmfs/bin'],
       unless  => "mmnfs config list -Y | grep -qi \":${_test_key}:${value}:\"",
     }
  }
}
