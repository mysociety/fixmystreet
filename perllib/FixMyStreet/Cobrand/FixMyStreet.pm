package FixMyStreet::Cobrand::FixMyStreet;
use base 'FixMyStreet::Cobrand::Default';

# FixMyStreet should return all cobrands
sub restriction {
    return {};
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

