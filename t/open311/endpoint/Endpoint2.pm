package t::open311::endpoint::Endpoint2;
use Web::Simple;
extends 't::open311::endpoint::Endpoint1';
with 'Open311::Endpoint::Role::mySociety';

sub get_service_request_updates {
    my ($self, $args) = @_;

    my $start_date = $self->maybe_inflate_datetime($args->{start_date});
    my $end_date   = $self->maybe_inflate_datetime($args->{end_date});

    my @requests = $self->filter_requests( sub { $_[0]->has_updates } );

    return map {
        $_->filter_updates( sub {
            my $update = shift;
            my $updated_datetime = $update->updated_datetime or return;
            if ($start_date) { return unless $updated_datetime >= $start_date }
            if ($end_date)   { return unless $updated_datetime <= $end_date }
            return 1;
        });
    } @requests;
}

1;
