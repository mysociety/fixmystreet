package FixMyStreet::App::Controller::JSON;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

use JSON;
use DateTime;
use DateTime::Format::ISO8601;

=head1 NAME

FixMyStreet::App::Controller::JSON - Catalyst Controller

=head1 DESCRIPTION

Provide information as JSON

=head1 METHODS

=head2 json

=cut

sub json : Path : Args(0) {
    my ( $self, $c ) = @_;

    # gather the parameters
    my $type       = $c->req->param('type')       || '';
    my $start_date = $c->req->param('start_date') || '';
    my $end_date   = $c->req->param('end_date')   || '';

    my $yyyy_mm_dd = qr{^\d{4}-\d\d-\d\d$};
    if (   $start_date !~ $yyyy_mm_dd
        || $end_date !~ $yyyy_mm_dd )
    {
        $c->stash->{error} = 'Invalid dates supplied';
        return;
    }

    # convert the dates to datetimes and trap errors
    my $iso8601  = DateTime::Format::ISO8601->new;
    my $start_dt = eval { $iso8601->parse_datetime($start_date); };
    my $end_dt   = eval { $iso8601->parse_datetime($end_date); };
    unless ( $start_dt && $end_dt ) {
        $c->stash->{error} = 'Invalid dates supplied';
        return;
    }

    # check that the dates are sane
    if ( $start_dt > $end_dt ) {
        $c->stash->{error} = 'Start date after end date';
        return;
    }

    # check that the type is supported
    unless ( $type eq 'new_problems' || $type eq 'fixed_problems' ) {
        $c->stash->{error} = 'Invalid type supplied';
        return;
    }

    # query the database
    $c->stash->{response} =
      $type eq 'new_problems'
      ? Problems::created_in_interval( $start_date, $end_date )
      : Problems::fixed_in_interval( $start_date, $end_date );
}

# If we convert this code to be fully DBIC based then the following snippet is a
# good start. The roadblock to doing it fully is the 'site_restriction' in the
# SQL which is currently provided as SQL, rather than something that could be
# easily added to the DBIC query. The hardest cobrand to change would be the
# cities - so perhaps do it after we know wether that needs to be kept or not.
#
# my $state =
#     $type eq 'new_problems'   ? 'confirmed'
#   : $type eq 'fixed_problems' ? 'fixed_problems'
#   :                             die;
#
# my $one_day = DateTime::Duration->new( days => 1 );
#
# my $problems = $c->model('DB::Problem')->search(
#     {
#         created => {
#             '>=' => $start_dt,
#             '<=' => $end_dt + $one_day,
#         },
#         state => $state,
#         # ------ add is site_restriction here -------
#     },
#     {
#         columns => [
#             'id',       'title', 'council',   'category',
#             'detail',   'name',  'anonymous', 'confirmed',
#             'whensent', 'service',
#         ]
#     }
# );

sub end : Private {
    my ( $self, $c ) = @_;

    my $response =
      $c->stash->{error}
      ? { error => $c->stash->{error} }
      : $c->stash->{response};

    $c->res->content_type('application/json; charset=utf-8');
    $c->res->body( encode_json( $response || {} ) );
}

__PACKAGE__->meta->make_immutable;

1;
