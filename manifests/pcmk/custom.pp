class storage::pcmk::custom(
) {
  require storage::pcmk::config

  if $storage::pcmk::config::primitives != undef {
    $storage::pcmk::config::primitives.each | $name, $options | {
      storage::pcmk::resource { "${name}":
        primitive_class => $options['primitive_class'],
        primitive_type  => $options['primitive_type'],
        provider        => $options['provided_by'],
        parameters      => $options['parameters'],
        operations      => $options['operations'],
        clone           => $options['clone'],
        ip              => $options['ip'],
        netmask         => $options['netmask'],
      }
    }
  }

  if $storage::pcmk::config::groups != undef {
    $storage::pcmk::config::groups.each | $name, $members | {
      storage::pcmk::resource {"${name}":
        primitives => $members,
        group      => true,
      }
    }
  }

  if $storage::pcmk::config::colocations != undef {
    $storage::pcmk::config::colocations.each | $name, $members | {
      storage::pcmk::resource {"${name}":
        primitives => $members,
        colocation => true,
      }
    }
  }

  if $storage::pcmk::config::orders != undef {
    $storage::pcmk::config::orders.each | $name, $members | {
      storage::pcmk::resource {"${name}":
        primitives => $members,
        order      => true,
      }
    }
  }
}
