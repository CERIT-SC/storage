define storage::cifs::ctdbnode (
   String $ip = undef,
   String $cfg = undef,
) {
    concat::fragment {"CTDB_node_${::fqdn}_$ip":
       target  => $cfg,
       content => "$ip\n",
       order   => 'numeric',
   }
}
