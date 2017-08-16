package FixMyStreet::Cobrand::Rutland;
use parent 'FixMyStreet::Cobrand::UKCouncils';

use strict;
use warnings;

sub council_area_id { return 2600; }
sub council_area { return 'Rutland'; }
sub council_name { return 'Rutland County Council'; }
sub council_url { return 'rutland'; }

sub example_places {
    return ( 'High Street', "Oakham" );
}

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    return {
        bounds => [52.524755166940075, -0.8217480325342802, 52.7597945702699, -0.4283542728893742]
    };
}

1;

__END__
sub council_area_id { return 2342; }
sub council_area { return 'East Hertfordshire'; }
sub council_name { return 'East Hertfordshire District Council'; }

sub base_url {
    my $self = shift;
    return $self->next::method() if FixMyStreet->config('STAGING_SITE');
    return 'https://fixmystreet.eastherts.gov.uk';
}


sub enter_postcode_text {
    my ($self) = @_;
    return 'Enter an ' . $self->council_area . ' postcode, or street name and area';
}

sub example_places {
    return ( 'SG14 2AP', "Mangrove Road" );
}

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    return {
        %{ $self->SUPER::disambiguate_location() },
        town => 'Hertford',
        centre => '51.8650537133491,-0.00819715483544082',
        span   => '0.26293637547365,0.379186581552513',
        bounds => [ 51.7341800736161, -0.18359132013981, 51.9971164490897, 0.195595261412703 ],
    };
}

sub pin_colour {
    my ( $self, $p, $context ) = @_;
    return 'grey' if $p->state eq 'not responsible';
    return 'green' if $p->is_fixed || $p->is_closed;
    return 'red' if $p->state eq 'confirmed';
    return 'yellow';
}

sub contact_email {
    my $self = shift;
    return join( '@', 'enquiries', 'eastherts.gov.uk' );
}

1;
1;
