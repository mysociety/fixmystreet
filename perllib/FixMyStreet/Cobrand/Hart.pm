package FixMyStreet::Cobrand::Hart;
use parent 'FixMyStreet::Cobrand::UKCouncils';

use strict;
use warnings;

sub council_id { return 2333; } # http://mapit.mysociety.org/area/2333.html
sub council_area { return 'Hart'; }
sub council_name { return 'Hart Council'; }
sub council_url { return 'hart'; }
sub is_two_tier { return 1; }

# Different to councils parent due to this being a two-tier council. If we get
# more, this can be genericised in the parent.
sub problems_clause {
    return { bodies_str => { like => '%2333%' } };
}

sub base_url {
    return FixMyStreet->config('BASE_URL') if FixMyStreet->config('STAGING_SITE');
    return 'https://fix.hart.gov.uk';
}

sub path_to_web_templates {
    my $self = shift;
    return [
        FixMyStreet->path_to( 'templates/web', $self->moniker )->stringify,
        FixMyStreet->path_to( 'templates/web/fixmystreet' )->stringify
    ];
}

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    my $town = 'Hart, Hampshire';

    return {
        %{ $self->SUPER::disambiguate_location() },
        town => $town,
        # these are taken from mapit http://mapit.mysociety.org/area/2333/geometry -- should be automated?
        centre => '51.284839,-0.8974600',
        span   => '0.180311,0.239375',
        bounds => [ 51.186005, -1.002295, 51.366316, -0.762920 ],
    };
}

sub example_places {
    return ( 'Branksomewood Rd', 'Primrose Dr' );
}

sub map_type {
    'Hart';
}

sub on_map_default_max_pin_age {
    return '1 month';
}

sub send_questionnaires {
    return 0;
}

sub ask_ever_reported {
    return 0;
}

sub process_extras {
    my $self = shift;
    $self->SUPER::process_extras( @_, [ 'first_name', 'last_name' ] );
}

sub contact_email {
    my $self = shift;
    return join( '@', 'info', 'hart.gov.uk' );
}
sub contact_name { 'Hart District Council (do not reply)'; }

sub reports_per_page { return 20; }

sub title_list {
    return ["MR", "MISS", "MRS", "MS", "DR"];
}

1;

