package FixMyStreet::Cobrand::Oxfordshire;
use base 'FixMyStreet::Cobrand::UKCouncils';

use strict;
use warnings;

sub council_id { return 2237; }
sub council_area { return 'Oxfordshire'; }
sub council_name { return 'Oxfordshire County Council'; }
sub council_url { return 'oxfordshire'; }
sub is_two_tier { return 1; }

sub base_url {
    return FixMyStreet->config('BASE_URL') if FixMyStreet->config('STAGING_SITE');
    return 'http://fixmystreet.oxfordshire.gov.uk';
}

sub enter_postcode_text {
    my ($self) = @_;
    return 'Enter an Oxfordshire postcode, or street name and area';
}

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;
    return {
        %{ $self->SUPER::disambiguate_location() },
        town   => 'Oxfordshire',
        centre => '51.765765,-1.322324',
        span   => '0.709058,0.849434',
        bounds => [ 51.459413, -1.719500, 52.168471, -0.870066 ],
    };
}

sub example_places {
    return ( 'OX20 1SZ', 'Park St, Woodstock' );
}

# don't send questionnaires to people who used the OCC cobrand to report their problem
sub send_questionnaires { return 0; }

# increase map zoom level so street names are visible
sub default_map_zoom { return 3; }

# let staff hide OCC reports
sub users_can_hide { return 1; }

sub default_show_name { 0 }

=head2 problem_response_days

Returns the number of working days that are expected to elapse
between the problem being reported and it being responded to by
the council/body.

=cut

sub problem_response_days {
    my $self = shift;
    my $p = shift;

    return 10 if $p->category eq 'Bridges';
    return 10 if $p->category eq 'Carriageway Defect'; # phone if urgent
    return 10 if $p->category eq 'Debris/Spillage';
    return 10 if $p->category eq 'Drainage';
    return 10 if $p->category eq 'Fences';
    return 10 if $p->category eq 'Flyposting';
    return 10 if $p->category eq 'Footpaths/ Rights of way (usually not tarmac)';
    return 10 if $p->category eq 'Gully and Catchpits';
    return 10 if $p->category eq 'Ice/Snow'; # phone if urgent
    return 10 if $p->category eq 'Manhole';
    return 10 if $p->category eq 'Mud and Debris'; # phone if urgent
    return 10 if $p->category eq 'Oil Spillage';  # phone if urgent
    return 10 if $p->category eq 'Pavements';
    return 10 if $p->category eq 'Pothole'; # phone if urgent
    return 10 if $p->category eq 'Property Damage';
    return 10 if $p->category eq 'Public rights of way';
    return 10 if $p->category eq 'Road Marking';
    return 10 if $p->category eq 'Road traffic signs';
    return 10 if $p->category eq 'Roads/highways';
    return 10 if $p->category eq 'Skips and scaffolding';
    return 10 if $p->category eq 'Street lighting';
    return 10 if $p->category eq 'Traffic lights'; # phone if urgent
    return 10 if $p->category eq 'Traffic';
    return 10 if $p->category eq 'Trees';
    return 10 if $p->category eq 'Utilities';
    return 10 if $p->category eq 'Vegetation';

    return undef;
}

sub reports_ordering {
    return { -desc => 'confirmed' };
}

sub pin_colour {
    my ( $self, $p, $context ) = @_;
    return 'grey' if $p->state eq 'not responsible';
    return 'green' if $p->is_fixed || $p->is_closed;
    return 'red' if $p->state eq 'confirmed';
    return 'yellow';
}

sub on_map_default_status { return 'open'; }

sub contact_email {
    my $self = shift;
    return join( '@', 'highway.enquiries', 'oxfordshire.gov.uk' );
}

1;
