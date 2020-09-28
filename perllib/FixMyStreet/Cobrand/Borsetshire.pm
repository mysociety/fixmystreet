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
    return 'grey' if $p->is_closed;
    return 'green' if $p->is_fixed;
    return 'yellow' if $p->state eq 'confirmed';
    return 'orange'; # all the other `open_states` like "in progress"
}

sub path_to_pin_icons {
    return '/cobrands/oxfordshire/images/';
}

sub send_questionnaires {
    return 0;
}

sub bypass_password_checks { 1 }


# Keyed by uprn
my $example_properties = {
    1001 => {
        id => 1,
        uprn => 1001,
        address => '1 Example Street, Borsetshire',
        latitude => 0,
        longitude => 0,
        services => [ {
            id => 2001,
            service_id => 3001,
            service_name => 'Blue bin',
            report_open => 0,
            request_open => 0,
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
            request_open => 0,
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
    1002 => {
        id => 2,
        uprn => 1002,
        address => '2 Example Street, Borsetshire',
        latitude => 0,
        longitude => 0,
    }
};

sub munge_around_category_where {
    my ($self, $where) = @_;
    $where->{extra} = [ undef, { -not_like => '%Waste%' } ];
}

sub munge_reports_category_list {
    my ($self, $categories) = @_;
    @$categories = grep { grep { $_ ne 'Waste' } @{$_->groups} } @$categories;
}

sub munge_report_new_contacts {
    my ($self, $categories) = @_;

    return if $self->{c}->action =~ /^waste/;

    @$categories = grep { grep { $_ ne 'Waste' } @{$_->groups} } @$categories;
    $self->SUPER::munge_report_new_contacts($categories);
}

sub bin_addresses_for_postcode {
    my $self = shift;
    my $pc = shift;

    my $data = [ map { {
        value => $_->{uprn},
        label => $_->{address}
    } } sort { $a->{address} cmp $b->{address} } values %$example_properties ];
    return $data;
}

sub look_up_property {
    my $self = shift;
    my $uprn = shift;

    return $example_properties->{$uprn};
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
