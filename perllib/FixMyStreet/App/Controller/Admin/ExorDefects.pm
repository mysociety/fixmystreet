package FixMyStreet::App::Controller::Admin::ExorDefects;
use Moose;
use namespace::autoclean;

use DateTime;
use Try::Tiny;
use FixMyStreet::Integrations::ExorRDI;
use FixMyStreet::DateRange;

BEGIN { extends 'Catalyst::Controller'; }


sub index : Path : Args(0) {
    my ( $self, $c ) = @_;

    foreach (qw(error_message start_date end_date user_id)) {
        if ( defined $c->flash->{$_} ) {
            $c->stash->{$_} = $c->flash->{$_};
        }
    }

    my @inspectors = $c->cobrand->users->search({
        'user_body_permissions.permission_type' => 'report_inspect'
    }, {
            join => 'user_body_permissions',
            distinct => 1,
        }
    )->all;
    $c->stash->{inspectors} = \@inspectors;

    # Default start/end date is today
    my $now = DateTime->now( time_zone => 
        FixMyStreet->time_zone || FixMyStreet->local_time_zone );
    $c->stash->{start_date} ||= $now;
    $c->stash->{end_date} ||= $now;

}

sub download : Path('download') : Args(0) {
    my ( $self, $c ) = @_;

    if ( !$c->cobrand->can('exor_rdi_link_id') ) {
        # This only works on the Oxfordshire cobrand currently.
        $c->detach( '/page_error_404_not_found', [] );
    }

    my $range = FixMyStreet::DateRange->new(
        start_date => $c->get_param('start_date'),
        end_date => $c->get_param('end_date'),
        parser => DateTime::Format::Strptime->new( pattern => '%Y-%m-%d' ),
    );

    my $params = {
        start_date => $range->start,
        inspection_date => $range->start,
        end_date => $range->end,
        user => $c->get_param('user_id'),
        mark_as_processed => 0,
    };
    my $rdi = FixMyStreet::Integrations::ExorRDI->new($params);

    try {
        my $out = $rdi->construct;
        $c->res->content_type('text/csv; charset=utf-8');
        $c->res->header('content-disposition' => "attachment; filename=" . $rdi->filename);
        $c->res->body( $out );
    } catch {
        die $_ unless $_ =~ /FixMyStreet::Integrations::ExorRDI::Error/;
        if ($params->{user}) {
            $c->flash->{error_message} = _("No inspections by that inspector in the selected date range.");
        } else {
            $c->flash->{error_message} = _("No inspections in the selected date range.");
        }
        $c->flash->{start_date} = $params->{start_date};
        $c->flash->{end_date} = $params->{end_date};
        $c->flash->{user_id} = $params->{user};
        $c->res->redirect( $c->uri_for( '' ) );
    };
}

1;
