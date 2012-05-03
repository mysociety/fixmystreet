package FixMyStreet::Cobrand::Barnet;
use base 'FixMyStreet::Cobrand::UKCouncils';

use strict;
use warnings;

sub council_id { return 2489; }
sub council_area { return 'Barnet'; }
sub council_name { return 'Barnet Council'; }
sub council_url { return 'barnet'; }
sub all_reports_style { return 'detailed'; }

sub path_to_web_templates {
    my $self = shift;
    return [
        FixMyStreet->path_to( 'templates/web', $self->moniker )->stringify,
        FixMyStreet->path_to( 'templates/web/fixmystreet' )->stringify
    ];
}

sub disambiguate_location {
    my $self = shift;
    return {
        %{ $self->SUPER::disambiguate_location() },
        centre => '51.612832,-0.218169',
        span   => '0.0563,0.09',
        bounds => [ '51.584682,-0.263169', '51.640982,-0.173169' ],
    };
}

sub generate_problem_banner {
    my ( $self, $problem ) = @_;

    my $banner = {};
    if ( $problem->is_open && time() - $problem->lastupdate_local->epoch > 8 * 7 * 24 * 60 * 60 )
    {
        $banner->{id}   = 'unknown';
        $banner->{text} = _('Unknown');
    }
    if ($problem->is_fixed) {
        $banner->{id} = 'fixed';
        $banner->{text} = _('Fixed');
    }
    if ($problem->is_closed) {
        $banner->{id} = 'closed';
        $banner->{text} = _('Closed');
    }

    if ( grep { $problem->state eq $_ } ( 'investigating', 'in progress', 'planned' ) ) {
        $banner->{id} = 'progress';
        $banner->{text} = _('In progress');
    }

    return $banner;
}

1;

