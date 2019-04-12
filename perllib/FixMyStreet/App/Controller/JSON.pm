package FixMyStreet::App::Controller::JSON;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

use JSON::MaybeXS;
use DateTime;
use DateTime::Format::ISO8601;
use List::MoreUtils 'uniq';
use FixMyStreet::DateRange;

=head1 NAME

FixMyStreet::App::Controller::JSON - Catalyst Controller

=head1 DESCRIPTION

Provide information as JSON

=head1 METHODS

=head2 problems

Provide JSON of new/fixed problems in a specified time range

=cut

sub problems : Local {
    my ( $self, $c, $path_type ) = @_;

    # get the type from the path - this is to deal with the historic url
    # structure. In futur
    $path_type ||= '';
    my $type =
        $path_type eq 'new'   ? 'new_problems'
      : $path_type eq 'fixed' ? 'fixed_problems'
      :                         '';

    # gather the parameters
    my $start_date = $c->get_param('start_date') || '';
    my $end_date = $c->get_param('end_date') || '';
    my $category = $c->get_param('category') || '';

    my $yyyy_mm_dd = qr{^\d{4}-\d\d-\d\d$};
    if (   $start_date !~ $yyyy_mm_dd
        || $end_date !~ $yyyy_mm_dd )
    {
        $c->stash->{error} = 'Invalid dates supplied';
        return;
    }

    # convert the dates to datetimes and trap errors
    my $range = FixMyStreet::DateRange->new(
        start_date => $start_date,
        end_date => $end_date,
        parser => DateTime::Format::ISO8601->new,
        formatter => $c->model('DB')->schema->storage->datetime_parser,
    );
    unless ($range->start && $range->end) {
        $c->stash->{error} = 'Invalid dates supplied';
        return;
    }

    # check that the dates are sane
    if ($range->start >= $range->end) {
        $c->stash->{error} = 'Start date after end date';
        return;
    }

    # check that the type is supported
    unless ( $type eq 'new_problems' || $type eq 'fixed_problems' ) {
        $c->stash->{error} = 'Invalid type supplied';
        return;
    }

    # query the database
    my ( @state, $date_col );
    if ( $type eq 'new_problems' ) {
        @state = FixMyStreet::DB::Result::Problem->open_states();
        $date_col = 'confirmed';
    } elsif ( $type eq 'fixed_problems' ) {
        @state = FixMyStreet::DB::Result::Problem->fixed_states();
        $date_col = 'lastupdate';
    }

    my $query = {
        $date_col => $range->sql,
        state => [ @state ],
        non_public => 0,
    };
    $query->{category} = $category if $category;
    my @problems = $c->cobrand->problems->search( $query, {
        order_by => { -asc => 'confirmed' },
        columns => [
            'id',       'title', 'bodies_str',   'category',
            'detail',   'name',  'anonymous', 'confirmed',
            'whensent', 'service',
            'latitude', 'longitude', 'used_map',
            'state', 'lastupdate',
        ]
    } );

    foreach my $problem (@problems) {
        $problem->name( '' ) if $problem->anonymous == 1;
        $problem->service( 'Web interface' ) if $problem->service eq '';
        my $body_names = $problem->body_names;
        if (@$body_names) {
             $problem->bodies_str( join(' and ', @$body_names) );
        }
    }

    @problems = map { { $_->get_columns } } @problems;
    $c->stash->{response} = \@problems;
}

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
