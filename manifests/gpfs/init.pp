class storage::gpfs::init (
) inherits storage::params {

    contain storage::gpfs::install
    contain storage::gpfs::config
    contain storage::gpfs::ces

}
