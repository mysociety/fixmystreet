package FixMyStreet::Cobrand::FixMyStreet;
use base 'FixMyStreet::Cobrand::Default';

# FixMyStreet should return all cobrands
sub restriction {
    return {};
}

sub get_council_sender {
    my ( $self, $area_id, $area_info ) = shift;

    my $sender_conf = mySociety::Config::get( 'SENDERS' );
    return $sender_conf->{ $council } if exists $sender_conf->{ $council };

    return 'London' if $area_info->{type} eq 'LBO';

    return 'Open311' if FixMyStreet::App->model("DB::Open311conf")->search( { area_id => $council, endpoint => { '!=', '' } } )->first;

    return 'Email';
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

