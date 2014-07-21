package t::open311::endpoint::Endpoint_Warwick;
use Web::Simple;

use Module::Loaded;
BEGIN {
    mark_as_loaded('DBD::Oracle');
}
our %BINDINGS;

extends 'Open311::Endpoint::Integration::Warwick';

sub insert_into_db {
    my ($self, $bindings) = @_;

    %BINDINGS = %$bindings;
    # return ($pem_id, $error_value, $error_product);
    return (1001);
}

1;
