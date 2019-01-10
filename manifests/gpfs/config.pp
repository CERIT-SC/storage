class storage::gpfs::config(
  Hash $attributes = undef,
) inherits storage::params {
  
  $attributes.each |$_k, $_v| {
     storage::gpfs::config::attribute {"gpfs_config_${_k}":
       ensure => 'present',
       key    => $_k,
       value  => $_v,
     }
  }
}
