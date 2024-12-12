package FixMyStreet::Cobrand::Borsetshire;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

sub council_area_id { return 2608; }
sub council_area { return 'Borsetshire'; }
sub council_name { return 'Borsetshire County Council'; }
sub council_url { return 'demo'; }

sub enter_postcode_text {
    my ($self) = @_;
    return 'Enter a UK postcode, or street name and area';
}

sub pin_colour {
    my ( $self, $p, $context ) = @_;
    return 'grey-cross' if $p->is_closed;
    return 'green-tick' if $p->is_fixed;
    return 'yellow-cone' if $p->state eq 'confirmed';
    return 'orange-work'; # all the other `open_states` like "in progress"
}

sub path_to_pin_icons { '/i/pins/whole-shadow-cone-spot/' }

sub send_questionnaires { 0 }

sub bypass_password_checks { 1 }

my $example_properties = {
    1 => {
        id => 1,
        uprn => 1001,
        address => '1 Example Street, Borsetshire',
        latitude => 51.53824,
        longitude => -2.39265,
        services => [ {
            id => 2001,
            service_id => 3001,
            service_name => 'Blue bin',
            report_open => 0,
            requests_open => {},
            report_allowed => 1,
            request_allowed => 1,
            request_containers => [ 6001, 6002 ],
            request_max => 2,
            enquiry_open_events => { },
            service_task_id => 4001,
            schedule => 'every Monday', # TODO!
            last => {
                date => DateTime->now->subtract(days=>2), # TODO!
                ordinal => 'th', # TODO!
                completed => DateTime->now->subtract(days=>2), # TODO!
            },
            next => {
                date => DateTime->now->add(days=>5), # TODO!
                ordinal => 'th', # TODO!
                changed => 0,
            },
        }, {
            id => 2002,
            service_id => 3002,
            service_name => 'Black bin',
            report_open => 0,
            requests_open => {},
            report_allowed => 1,
            request_allowed => 1,
            request_containers => [ 6003 ],
            request_max => 2,
            enquiry_open_events => { },
            service_task_id => 4002,
            schedule => 'every Wednesday', # TODO!
            last => {
                date => DateTime->now->subtract(days=>2), # TODO!
                ordinal => 'th', # TODO!
                completed => DateTime->now->subtract(days=>2), # TODO!
            },
            next => {
                date => DateTime->now->add(days=>5), # TODO!
                ordinal => 'th', # TODO!
                changed => 0,
            },
        } ]
    },
    2 => {
        id => 2,
        uprn => 1002,
        address => '2 Example Street, Borsetshire',
        latitude => 51.53824,
        longitude => -2.39265,
    }
};

sub bin_addresses_for_postcode {
    my $self = shift;
    my $pc = shift;

    my $data = [ map { {
        value => $_->{id},
        label => $_->{address}
    } } sort { $a->{address} cmp $b->{address} } values %$example_properties ];
    return $data;
}

sub look_up_property {
    my $self = shift;
    my $property_id = shift;

    return $example_properties->{$property_id};
}

my %irregulars = ( 1 => 'st', 2 => 'nd', 3 => 'rd', 11 => 'th', 12 => 'th', 13 => 'th');
sub ordinal {
    my $n = shift;
    $irregulars{$n % 100} || $irregulars{$n % 10} || 'th';
}

sub bin_services_for_address {
    my $self = shift;
    my $property = shift;

    $self->{c}->stash->{containers} = {
        6001 => 'Blue box (paper and plastic)',
        6002 => 'Blue wheeled bin (paper and plastic)',
        6003 => 'Black wheeled bin (general waste)',
    };

    return $property->{services};
}

sub bin_future_collections {
    my $self = shift;
    return [];
}

1;
