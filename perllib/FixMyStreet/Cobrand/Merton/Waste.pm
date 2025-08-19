package FixMyStreet::Cobrand::Merton::Waste;

use utf8;
use Moo::Role;
with 'FixMyStreet::Roles::Cobrand::Waste',
     'FixMyStreet::Roles::Cobrand::SLWP',
     'FixMyStreet::Roles::Cobrand::Adelante';

use Hash::Util qw(lock_hash);
use WasteWorks::Costs;
use FixMyStreet::App::Form::Waste::Report::Merton;
use FixMyStreet::App::Form::Waste::Request::Merton;
use FixMyStreet::App::Form::Waste::Request::Merton::Larger;

my %TASK_IDS = (
    domestic_refuse => 2238,
    domestic_food => 2239,
    domestic_paper => 2240,
    domestic_mixed => 2241,
    domestic_refuse_bag => 2242,
    communal_refuse => 2243,
    domestic_mixed_bag => 2246,
    garden => 2247,
    communal_food => 2248,
    communal_paper => 2249,
    communal_mixed => 2250,
    domestic_paper_bag => 2632,
    schedule2_mixed => 3571,
    schedule2_refuse => 3576,
    deliver_refuse_bags => 2256,
    deliver_recycling_bags => 2257,
);
lock_hash(%TASK_IDS);

use constant CONTAINER_RECYCLING_PURPLE_BAG => 17;

=over 4

=item * As Merton shares An Echo, we use NLPG to restrict results to Merton

=cut

has lpi_value => ( is => 'ro', default => 'MERTON' );

=item * Merton has a Saturday 1 July date format

=cut

sub bin_day_format { '%A %-d %B' }

=item * Merton calendars only look two weeks into the future

=cut

sub bin_future_timeframe { ( days => 15 ) }

sub waste_check_staff_payment_permissions {
    my $self = shift;
    my $c = $self->{c};

    return unless $c->stash->{is_staff};

    $c->stash->{staff_payments_allowed} = 'cnp';
}

sub waste_auto_confirm_report { 1 }

sub waste_cancel_asks_staff_for_user_details { 1 }

sub service_name_override {
    my ($self, $service) = @_;

    my %service_name_override = (
        $TASK_IDS{domestic_refuse} => 'Non-recyclable waste',
        $TASK_IDS{domestic_food} => 'Food waste',
        $TASK_IDS{domestic_paper} => 'Paper and card',
        $TASK_IDS{domestic_mixed} => 'Mixed recycling',
        $TASK_IDS{domestic_refuse_bag} => 'Non-recyclable waste',
        $TASK_IDS{communal_refuse} => 'Non-recyclable waste',
        $TASK_IDS{domestic_mixed_bag} => 'Mixed recycling',
        $TASK_IDS{garden} => 'Garden Waste',
        $TASK_IDS{communal_food} => 'Food waste',
        $TASK_IDS{communal_paper} => 'Paper and card',
        $TASK_IDS{communal_mixed} => 'Mixed recycling',
        $TASK_IDS{domestic_paper_bag} => 'Paper and card',
        $TASK_IDS{deliver_refuse_bags} => '',
        $TASK_IDS{deliver_recycling_bags} => '',
    );

    return $service_name_override{$service->{ServiceId}} // '';
}

sub waste_password_hidden { 1 }

sub waste_containers {
    return {
        1 => 'Black rubbish bin (140L)',
        2 => 'Black rubbish bin (240L)',
        3 => 'Black rubbish bin (360L)',
        35 => 'Black rubbish bin (180L)',

        4 => 'Refuse Blue Sack',
        5 => 'Refuse Black Sack',
        6 => 'Refuse Red Stripe Bag',

        12 => 'Green recycling bin (240L)',
        13 => 'Green recycling bin (360L)',
        16 => 'Green recycling box (55L)',

        CONTAINER_RECYCLING_PURPLE_BAG() => 'Recycling Purple Bag',
        18 => 'Recycling Blue Stripe Bag',
        29 => 'Recycling Single Use Bag',

        19 => 'Blue lid paper and cardboard bin (240L)',
        20 => 'Blue lid paper and cardboard bin (360L)',
        36 => 'Blue lid paper and cardboard bin (180L)',

        21 => 'Paper & Card Reusable Bag',
        22 => 'Paper Sacks',
        30 => 'Paper Single Use Bag',
        31 => 'Paper 55L Box',

        23 => 'Food waste bin (kitchen)',
        24 => 'Food waste bin (outdoor)',

        26 => 'Garden waste bin (240L)',
        27 => 'Garden waste bin (140L)',
        28 => 'Garden waste sacks',

        7 => 'Communal Refuse bin (240L)',
        8 => 'Communal Refuse bin (360L)',
        9 => 'Communal Refuse bin (660L)',
        10 => 'Communal Refuse bin (1100L)',
        11 => 'Communal Refuse Chamberlain',
        33 => 'Communal Refuse bin (140L)',
        34 => 'Communal Refuse bin (1280L)',
        14 => 'Communal Recycling bin (660L)',
        15 => 'Communal Recycling bin (1100L)',
        25 => 'Communal Food bin (240L)',
    };
}

sub _waste_containers_no_request { {
    4 => 1, # Refuse blue bag
    29 => 1, # Recycling Single Use Bag
    21 => 1, # Paper & Card Reusable bag
} }

sub image_for_unit {
    my ($self, $unit) = @_;
    my $base = '/i/waste-containers';
    my $service_id = $unit->{service_id};
    my $time_banded = $self->{c}->stash->{property_time_banded};

    return svg_container_sack('normal', '#3B3B3A') if $service_id eq $TASK_IDS{domestic_refuse_bag} && $time_banded;
    if (my $container = $unit->{request_containers}[0]) {
        return svg_container_sack('normal', '#BD63D1') if $container == CONTAINER_RECYCLING_PURPLE_BAG;
    }

    my $images = {
        $TASK_IDS{domestic_refuse} => svg_container_bin('wheelie', '#333333'),
        $TASK_IDS{domestic_food} => "$base/caddy-brown-large",
        '2239-batteries' => {
            alt => 'These should be presented in an untied carrier bag.',
            type => 'png1',
            src => "$base/merton/bag-untied-orange",
        },
        $TASK_IDS{domestic_paper} => svg_container_bin("wheelie", '#767472', '#00A6D2', 1),
        $TASK_IDS{domestic_mixed} => "$base/box-green-mix",
        $TASK_IDS{domestic_refuse_bag} => svg_container_sack('stripe', '#F1506D'),
        $TASK_IDS{communal_refuse} => svg_container_bin('communal', '#767472', '#333333'),
        $TASK_IDS{domestic_mixed_bag} => svg_container_sack('stripe', '#3E50FA'),
        $TASK_IDS{garden} => svg_container_bin('wheelie', '#8B5E3D'),
        $TASK_IDS{communal_food} => svg_container_bin('wheelie', '#8B5E3D'),
        $TASK_IDS{communal_mixed} => svg_container_bin('communal', '#41B28A'),
        $TASK_IDS{domestic_paper_bag} => svg_container_sack('normal', '#D8D8D8'),
        bulky => "$base/bulky-black",
    };
    return $images->{$service_id};
}

sub garden_collection_time { '6:00am' }

sub waste_renewal_bins_wanted_disabled { 1 }

=item * SLWP Echo uses End_Date for garden cancellations

=cut

sub alternative_backend_field_names {
    my ($self, $field) = @_;

    my %alternative_name = (
        'Subscription_End_Date' => 'End_Date',
    );

    return $alternative_name{$field};
}

sub waste_garden_maximum { 3 }

=item munge_bin_services_for_address

Merton want staff to be able to request any domestic container
for a property and also to not be restricted to only ordering
one container. And they want to show special battery
options.

=cut

sub munge_bin_services_for_address {
    my ($self, $rows) = @_;

    return if $self->{c}->stash->{schedule2_property};

    foreach (@$rows) {
        if ($_->{service_id} eq $TASK_IDS{domestic_food}) {
            # Add battery options at the bottom
            my $new_row = {
                %$_,
                report_allowed => 0,
                report_locked_out => 0,
                report_open => 0,
                request_allowed => 0,
                requests_open => {},
                request_containers => [], # request_allowed not enough
                orange_bag => 1,
                service_id => '2239-batteries',
                service_name => 'Batteries',
            };
            push @$rows, $new_row;
        }
    }

    return unless $self->{c}->stash->{is_staff};

    my @containers_on_property;

    foreach my $row (@$rows) {
        next if $row->{orange_bag}; # Ignore batteries
        next unless $row->{request_containers};
        push @containers_on_property, @{$row->{request_containers}};
        $row->{request_allowed} = 1;
        $row->{request_max} = 3;
    }

    my %new_row = (
        service_id => 'other_containers',
        service_name => 'Other containers',
        request_containers => [],
        request_only => 1,
        request_allowed => 1,
        request_max => 3,
    );

    my %all_containers = reverse %{$self->waste_containers};
    foreach my $v (sort { $a cmp $b } keys %all_containers) {
        next if $v =~ /Communal/;
        my $k = $all_containers{$v};
        next if grep { $k == $_ } @containers_on_property;
        push @{$new_row{request_containers}}, $k;
    }

    push @$rows, \%new_row;
}

=head2 waste_munge_request_form_pages

Larger bin request has a separate request flow

=cut

sub waste_munge_request_form_pages {
    my ($self, $page_list, $field_list) = @_;
    my $c = $self->{c};

    if ($c->get_param('exchange')) {
        $c->stash->{first_page} = 'medical_condition';
        $c->stash->{form_class} = "FixMyStreet::App::Form::Waste::Request::Merton::Larger";
    }
}

sub waste_request_form_first_next {
    my $self = shift;
    return sub {
        my $data = shift;
        return 'about_you' if $data->{"container-18"} || $data->{"container-30"};
        return 'replacement';
    };
}

sub waste_munge_request_form_fields {
    my ($self, $field_list) = @_;

    for (my $i=0; $i<@$field_list; $i+=2) {
        my ($key, $value) = ($field_list->[$i], $field_list->[$i+1]);
        next unless $key =~ /^container-(\d+)/;
        my $id = $1;
        my $cost = $self->request_cost($id);
        if ($cost) {
            my $price = sprintf("£%.2f", $cost / 100);
            $price =~ s/\.00$//;
            $value->{option_hint} = "There is a $price cost for this container";
        }
    }
}

=head2 request_cost

Calculate how much, if anything, a request for a container should be.

=cut

sub request_cost {
    my ($self, $id) = @_;
    my $costs = WasteWorks::Costs->new({ cobrand => $self });
    my $cost = $costs->get_cost('request_cost_' . $id);
    return $cost;
}

sub waste_munge_request_data {
    my ($self, $id, $data, $form) = @_;

    my $c = $self->{c};
    my $address = $c->stash->{property}->{address};
    my $container = $c->stash->{containers}{$id};
    my $quantity = $data->{"quantity-$id"} || 1;
    my $reason = $data->{request_reason} || '';
    my $nice_reason = $c->stash->{label_for_field}->($form, 'request_reason', $reason)
        if $reason;

    my ($action_id, $reason_id);
    my $echo_container_id = $id;
    if ($data->{medical_condition}) { # Filled in the larger form
        $reason = 'change_capacity';
        $action_id = '2::1';
        $reason_id = '3::3';
        $echo_container_id = '35::2';
    } elsif ($reason eq 'damaged') {
        $action_id = 3; # Replace
        $reason_id = 2; # Damaged
    } elsif ($reason eq 'missing') {
        $action_id = 1; # Deliver
        $reason_id = 1; # Missing
    } elsif ($reason eq 'new_build') {
        $action_id = 1; # Deliver
        $reason_id = 4; # New
    } elsif ($reason eq 'more') {
        $action_id = 1; # Deliver
        $reason_id = 3; # Change capacity
    } else {
        # No reason, must be a bag
        $action_id = 1; # Deliver
        $reason_id = 3; # Change capacity
        $nice_reason = "Additional bag required";
    }

    if ($reason eq 'damaged' || $reason eq 'missing') {
        $data->{title} = "Request replacement $container";
    } elsif ($reason eq 'change_capacity') {
        $data->{title} = "Request exchange for $container";
    } else {
        $data->{title} = "Request new $container";
    }
    $data->{detail} = "Quantity: $quantity\n\n$address";
    $data->{detail} .= "\n\nReason: $nice_reason" if $nice_reason;
    if ($data->{request_reason_text}) {
        $data->{detail} .= "\n\nAdditional details: " . $data->{request_reason_text};
        $c->set_param('Notes', $data->{request_reason_text});
    }
    $c->set_param('Action', join('::', ($action_id) x $quantity));
    $c->set_param('Reason', join('::', ($reason_id) x $quantity));
    $c->set_param('Container_Type', $echo_container_id);

    if ($data->{payment}) {
        my $cost = $self->request_cost($id);
        $c->set_param('payment', $cost || undef); # Want to undefine it if free
    }
}

sub garden_due_days { 30 }

=head2 waste_munge_report_form_pages

Rename the button on the first report page if we're doing an additional collection

=cut

sub waste_munge_report_form_pages {
    my ($self, $page_list, $field_list) = @_;
    if ($self->{c}->get_param('additional')) {
        $page_list->[1]->{title} = 'Select additional collection';
        $page_list->[1]->{update_field_list} = sub {
            return { submit => { value => 'Request additional collection' } };
        };
    }
}

sub waste_munge_report_form_fields {
    my ($self, $field_list) = @_;
    $self->{c}->stash->{form_class} = 'FixMyStreet::App::Form::Waste::Report::SLWP';
}

sub waste_munge_enquiry_data {
    my ($self, $data) = @_;

    my $address = $self->{c}->stash->{property}->{address};
    $data->{title} = $data->{category};

    my $detail;
    if ($data->{category} eq 'Bin not returned') {
        $detail .= ($data->{'extra_Report_Type'} eq '1' ? 'Bin position' : 'Lid not closed') . "\n\n";
        $detail .= ($data->{'extra_Crew_Required_to_Return?'} eq '1' ? 'Request bin collectors return'
            : 'No request for bin collectors return') ."\n\n";
        $detail .= ($data->{'extra_Notes'} ? $data->{'extra_Notes'} : '') . "\n\n";
    } else {
        foreach (sort grep { /^extra_/ } keys %$data) {
            $detail .= "$data->{$_}\n\n";
        }
    }
    $detail .= $address;
    $data->{detail} = $detail;
}

=head2 Payment information

=cut

sub waste_payment_ref_council_code { 'LBM' }

sub waste_cc_payment_reference {
    my ($self, $p) = @_;
    my $type = 'GWS'; # Garden
    $type = 'BWC' if $p->category eq 'Bulky collection';
    $type = 'RNC' if $p->category eq 'Request new container';
    return $self->waste_payment_ref_council_code . "-$type-" . $p->id;
}

sub check_ggw_transfer_applicable {
    my ($self, $old_address) = @_;

    # Check new address doesn't have a ggw subscription
    return { error => 'current' } if $self->garden_current_subscription;

    # Check that the old address has a ggw subscription and it's not
    # in its expiry period
    my $details = $self->look_up_property($old_address);
    my $old_services = $self->{api_serviceunits};

    my ($old_garden) = grep { $_->{ServiceId} eq '409' } @$old_services;
    $old_garden->{transfer_uprn} = $details->{uprn};

    my $servicetask = $self->garden_current_service_from_service_units($old_services);

    return { error => 'no_previous' } unless $servicetask;

    my $subscription_enddate = _parse_schedules($servicetask)->{end_date};
    return { error => 'due_soon' } if ($subscription_enddate && $self->waste_sub_due($subscription_enddate));

    my $old_subscription_bin_data = Integrations::Echo::force_arrayref($servicetask->{Data}, 'ExtensibleDatum');

    foreach (@$old_subscription_bin_data) {
        my $moredata = Integrations::Echo::force_arrayref($_->{ChildData}, 'ExtensibleDatum');
        foreach (@$moredata) {
            if ($_->{DatatypeName} eq 'Quantity') {
                $old_garden->{transfer_bin_number} = $_->{Value};
            } elsif ($_->{DatatypeName} eq 'Container Type') {
                $old_garden->{transfer_bin_type} = $_->{Value};
            }
        }
    };
    $old_garden->{subscription_enddate} = $subscription_enddate;
    return $old_garden;
}

=head2 Bulky waste collection

Merton has a 6am collection and cut-off for cancellation time.
Everything else is configured in SLWP/Echo.

=cut

sub bulky_collection_time { { hours => 6, minutes => 0 } }
sub bulky_cancellation_cutoff_time { { hours => 6, minutes => 0 } }
sub bulky_allowed_property {
    my ( $self, $property ) = @_;
    return 1 if $self->bulky_enabled && $property->{has_bulky_service};
}
sub bulky_collection_window_days { 28 }

=item bulky_open_overdue

Returns true if the booking is open and after 6pm on the day of the collection.

=cut

sub bulky_open_overdue {
    my ($self, $event) = @_;

    if ($event->{state} eq 'open' && $self->_bulky_collection_overdue($event)) {
        return 1;
    }
}

sub _bulky_collection_overdue {
    my $collection_due_date = $_[1]->{date};
    $collection_due_date->truncate(to => 'day')->set_hour(18);
    my $today = DateTime->now->set_time_zone(FixMyStreet->local_time_zone);
    return $today > $collection_due_date;
}

1;
