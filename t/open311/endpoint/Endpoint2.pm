package t::open311::endpoint::Endpoint2;
use Web::Simple;
extends 't::open311::endpoint::Endpoint1';
with 'Open311::Endpoint::Role::mySociety';

sub get_service_request_updates {
    my ($self, $args) = @_;

    my $start_date = $self->maybe_inflate_datetime($args->{start_date});
    my $end_date   = $self->maybe_inflate_datetime($args->{end_date});

    return $self->filter_requests( sub {
        my $request = shift;
        my $updated_datetime = $request->updated_datetime or return;
        if ($start_date) { return unless $updated_datetime >= $start_date }
        if ($end_date)   { return unless $updated_datetime <= $end_date }
        warn $updated_datetime;
        return 1;
    });
}

1;
