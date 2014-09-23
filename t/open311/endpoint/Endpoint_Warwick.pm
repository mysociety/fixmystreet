package t::open311::endpoint::Endpoint_Warwick;
use Web::Simple;

our %BINDINGS;
our $UPDATES_SQL;

extends 'Open311::Endpoint::Integration::Warwick';

sub insert_into_db {
    my ($self, $bindings) = @_;

    %BINDINGS = %$bindings;
    # return ($pem_id, $error_value, $error_product);
    return (1001);
}

sub get_updates_from_sql {
    my ($self, $sql) = @_;
    $UPDATES_SQL = $sql;
    return (
        {
            row_id => 999,
            service_request_id => 1001,
            updated_datetime => '2014-07-23 11:07:00',
            status => 'closed',
            description => 'Closed the ticket',
        }
    );
}

1;
