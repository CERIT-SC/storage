class storage::nfs::init (
) inherits storage::params {

    contain storage::nfs::install
    contain storage::nfs::config

}
