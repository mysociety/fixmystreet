package Open311::GetServiceRequestUpdates;

use Moo;
extends 'Open311::UpdatesBase';

use Readonly;
use DateTime::Format::W3CDTF;

has '+send_comments_flag' => ( default => 1 );
has start_date => ( is => 'ro', default => sub { undef } );
has end_date => ( is => 'ro', default => sub { undef } );

has comments_created => ( is => 'rw', default => 0 );

Readonly::Scalar my $AREA_ID_BROMLEY     => 2482;
Readonly::Scalar my $AREA_ID_OXFORDSHIRE => 2237;

sub parse_dates {
    my $self = shift;
    my $body = $self->current_body;

    my @args = ();

    my $dt = DateTime->now();
    # Oxfordshire uses local time and not UTC for dates
    FixMyStreet->set_time_zone($dt) if $body->areas->{$AREA_ID_OXFORDSHIRE};

    # default to asking for last 2 hours worth if not Bromley
    if ($self->start_date) {
        push @args, DateTime::Format::W3CDTF->format_datetime( $self->start_date );
    } elsif ( ! $body->areas->{$AREA_ID_BROMLEY} ) {
        my $start_dt = $dt->clone->add( hours => -2 );
        push @args, DateTime::Format::W3CDTF->format_datetime( $start_dt );
    }

    if ($self->end_date) {
        push @args, DateTime::Format::W3CDTF->format_datetime( $self->end_date );
    } elsif ( ! $body->areas->{$AREA_ID_BROMLEY} ) {
        push @args, DateTime::Format::W3CDTF->format_datetime( $dt );
    }

    return @args;
}

sub process_body {
    my $self = shift;

    my $open311 = $self->current_open311;
    my $body = $self->current_body;
    my @args = $self->parse_dates;
    my $requests = $open311->get_service_request_updates( @args );

    unless ( $open311->success ) {
        warn "Failed to fetch ServiceRequest Updates for " . $body->name . ":\n" . $open311->error
            if $self->verbose;
        return 0;
    }

    $self->process_requests($requests, \@args);

    return 1;
}

sub process_requests {
    my ($self, $requests, $args) = @_;

    my $created = 0;
    for my $request (@$requests) {
        next unless defined $request->{update_id};

        my $p = $self->find_problem($request, @$args) or next;
        my $c = $p->comments->search( { external_id => $request->{update_id} } );
        next if $c->first;

        $created++;

        $self->process_update($request, $p);
    }
    $self->comments_created( $created );
}

sub _find_problem {
    my ($self, $criteria) = @_;
    my $problem = $self->schema->resultset('Problem')
        ->to_body($self->current_body)
        ->search( $criteria );
    return $problem->first;
}

1;
