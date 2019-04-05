define storage::pcmk::resource(
  String $resource_name             = $title,
  Optional[String] $primitive_class = undef,
  Optional[String] $primitive_type  = undef,
  Optional[String] $provider        = undef,
  Optional[Hash] $parameters        = undef,
  Optional[Hash] $operations        = undef,
  Boolean $clone                    = false,
  Optional[String] $ip              = undef,
  String $netmask                   = "255.255.255.0",
  Boolean $present                  = true,
  Boolean $group                    = false,
  Boolean $colocation               = false,
  Boolean $order                    = false,
  Boolean $only_clone               = false,
  Optional[Array] $primitives       = undef,
) {
  require storage::pcmk::config
  if ( ! $group ) and ( ! $colocation ) and ( ! $order ) and ( ! $only_clone ) {
    if $present {
      cs_primitive{"${resource_name}":
        ensure          => present,
        primitive_class => $class,
        primitive_type  => $type,
        provided_by     => $provider,
        parameters      => $parameters,
        operations      => $operations,
      }

      if $clone {
        storage::pcmk::resource{"${resource_name}-clone":
          only_clone => true,
          primitives => [$resource_name],
        }
      }

      if $ip != undef {
        storage::pcmk::resource{"${resource_name}-ip":
          primitive_class => 'ocf',
          primitive_type  => 'IPaddr2',
          provider        => 'heartbeat',
          parameters      => { 'ip' => $ip, 'cidr_netmask' => $netmask },
          operations      => {
            'monitor' => { 'interval' => '10s', 'timeout' => '30s', 'on-fail' => 'restart' },
            'start'   => { 'interval' => '0', 'timeout' => '60s', 'on-fail' => 'restart' },
          },
          require         => Cs_primitive["${resource_name}"],
        }
        if $clone {
          cs_order {"${resource_name}-order-ip":
            ensure  => present,
            first   => "${resource_name}-clone",
            second  => "${resource_name}-ip",
            kind    => 'Mandatory',
            require => Cs_primitive["${resource_name}-ip"],
          }
        } else {
          cs_order {"${resource_name}-order-ip":
            ensure  => present,
            first   => $resource_name,
            second  => "${resource_name}-ip",
            kind    => 'Mandatory',
            require => Cs_primitive["${resource_name}-ip"],
          }
        }
      }
    } else {
      if $ip != undef {
        cs_order {"${resource_name}-order-ip":
          ensure => absent,
          first  => $resoruce_name,
          second => "${resource_name}-ip",
          kind   => 'Mandatory',
        }
        cs_primitive{"${resource_name}-ip":
          ensure          => absent,
          primitive_class => 'ocf',
          primitive_type  => 'IPaddr2',
          provided_by     => 'heartbeat',
          operations      => {
            'monitor' => { 'interval' => '10s', 'timeout' => '30s', 'on-fail' => 'restart' },
            'start'   => { 'interval' => '0', 'timeout' => '60s', 'on-fail' => 'restart' },
          }
        }
      }

      if $clone {
        storage::pcmk::resource{"${resource_name}-clone":
          present    => false,
          only_clone => true,
          primitives => [$resource_name],
        }
      }

      cs_primitive{"${resource_name}":
        ensure          => absent,
        primitive_class => $class,
        primitive_type  => $type,
        provided_by     => $provider,
        operations      => $operations,
      }
    }
  } else {
    $requires = $primitives.reduce([]) | Array $memo, String $primitive | {
      concat($memo, Storage::Pcmk::Resource[$primitive])
    }
    if $group {
      if $present {
        cs_group { "${resource_name}":
          ensure     => present,
          primitives => $primitives,
          require    => $requires,
        }
      } else {
        cs_group { "${resource_name}":
          ensure => absent,
          primitives => $primitives,
        }
      }
    } elsif $colocation {
      if $present {
        cs_colocation { "${resource_name}":
          ensure     => present,
          primitives => $primitives,
          require    => $requires,
        }
      } else {
        cs_colocation { "${resource_name}":
          ensure => absent,
          primitives => $primitives,
        }
      }
    } elsif $order {
      if $present {
        cs_order { "${resource_name}":
          ensure  => present,
          first   => $primitives[0],
          second  => $primitives[1],
          require => [
            Storage::Pcmk::Resource[$primitives[0]],
            Storage::Pcmk::Resource[$primitives[1]],
          ],
        }
      } else {
        cs_order { "${resource_name}":
          ensure => absent,
          first   => $primitives[0],
          second  => $primitives[1],
        }
      }
    } elsif $only_clone {
      if $present {
        cs_clone{"${resource_name}":
          ensure    => present,
          primitive => $primitives[0],
          require   => Cs_primitive[$primitives[0]],
        }
      } else {
        cs_clone{"${resource_name}":
          ensure    => absent,
          primitive => $primitives[0],
        }
      }
    }
  }
}
