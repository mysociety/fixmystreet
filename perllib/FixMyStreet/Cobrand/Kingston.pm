=head1 NAME

FixMyStreet::Cobrand::Kingston - code specific to the Kingston cobrand

=head1 SYNOPSIS

Kingston is a London borough, we integrate with Echo for WasteWorks.

=head1 DESCRIPTION

=cut

package FixMyStreet::Cobrand::Kingston;
use parent 'FixMyStreet::Cobrand::UKCouncils';

use utf8;
use Moo;
with 'FixMyStreet::Roles::Cobrand::Waste',
     'FixMyStreet::Roles::Cobrand::KingstonSutton',
     'FixMyStreet::Roles::Cobrand::SLWP2',
     'FixMyStreet::Roles::Cobrand::SCP';

use Lingua::EN::Inflect qw( NUMWORDS );
use Hash::Util qw(lock_hash);

sub council_area_id { return 2480; }
sub council_area { return 'Kingston'; }
sub council_name { return 'Kingston upon Thames Council'; }
sub council_url { return 'kingston'; }
sub admin_user_domain { 'kingston.gov.uk' }

=head2 wasteworks_only

Configuration for cobrands which don't have street reporting.
Currently in use for the ooh messages on the admin page to
remove unnecessary fields.

=cut

sub wasteworks_only { 1 }

my %SERVICE_IDS = (
    domestic_refuse => 966, # 4394
    communal_refuse => 969, # 4407
    fas_refuse => 967, # 4395
    domestic_mixed => 970, # 4390
    communal_mixed => 973, # 4397
    fas_mixed => 971, # 4391
    domestic_paper => 974, # 4388
    communal_paper => 977, # 4396
    fas_paper => 975, # 4402
    domestic_food => 980, # 4389
    communal_food => 983, # 4403
    garden => 979, # 4410
    schedule2_refuse => 968, # 4409
    schedule2_mixed => 972, # 4398
    deliver_bags => 987, # 4427 4432
);
lock_hash(%SERVICE_IDS);

my %CONTAINERS = (
    refuse_140 => 1,
    refuse_180 => 2,
    refuse_240 => 3,
    refuse_360 => 4,
    refuse_1100 => 8,
    refuse_bag => 10,
    recycling_box => 12,
    recycling_240 => 15,
    recycling_360 => 16,
    recycling_1100 => 20,
    recycling_blue_bag => 22,
    paper_240 => 27,
    paper_140 => 26,
    paper_360 => 28,
    paper_1100 => 32,
    paper_bag => 34,
    food_indoor => 43,
    food_outdoor => 46,
    food_240 => 51,
    garden_240 => 39,
    garden_140 => 37,
    garden_sack => 36,
);
lock_hash(%CONTAINERS);

=head2 waste_check_staff_payment_permissions

Staff take payments off-session, then enter an authorization code on our site.

=cut

sub waste_check_staff_payment_permissions {
    my $self = shift;
    my $c = $self->{c};

    return unless $c->stash->{is_staff};

    $c->stash->{staff_payments_allowed} = 'paye';
}

=head2 Garden waste

=over 4

=item * Line items will include an RBK prefix

=item * Garden collection is from 6:30am

=item * Garden subscriptions are 5 bins maximum

=back

=cut

sub waste_payment_ref_council_code { "RBK" }

sub garden_collection_time { '6:30am' }

sub waste_garden_maximum { 5 }

sub waste_munge_bin_services_open_requests {
    my ($self, $open_requests) = @_;
    if ($open_requests->{$CONTAINERS{refuse_140}}) { # Sutton
        $open_requests->{$CONTAINERS{refuse_240}} = $open_requests->{$CONTAINERS{refuse_140}};
    } elsif ($open_requests->{$CONTAINERS{refuse_180}}) { # Kingston
        $open_requests->{$CONTAINERS{refuse_240}} = $open_requests->{$CONTAINERS{refuse_180}};
    } elsif ($open_requests->{$CONTAINERS{refuse_240}}) { # Both
        $open_requests->{$CONTAINERS{refuse_140}} = $open_requests->{$CONTAINERS{refuse_240}};
        $open_requests->{$CONTAINERS{refuse_180}} = $open_requests->{$CONTAINERS{refuse_240}};
        $open_requests->{$CONTAINERS{refuse_360}} = $open_requests->{$CONTAINERS{refuse_240}};
    } elsif ($open_requests->{$CONTAINERS{refuse_360}}) { # Kingston
        $open_requests->{$CONTAINERS{refuse_180}} = $open_requests->{$CONTAINERS{refuse_360}};
        $open_requests->{$CONTAINERS{refuse_240}} = $open_requests->{$CONTAINERS{refuse_360}};
    }
    if ($open_requests->{$CONTAINERS{paper_140}}) {
        $open_requests->{$CONTAINERS{paper_240}} = $open_requests->{$CONTAINERS{paper_140}};
    }

    my $wd = FixMyStreet::WorkingDays->new();
    for my $req (values %$open_requests) {
        next unless $req;
        $req->{expected_date} = $wd->add_days($req->{date}, $self->wasteworks_config->{request_timeframe_raw})->set_hour(0);
    }
}

sub image_for_unit {
    my ($self, $unit) = @_;
    my $base = '/i/waste-containers';
    if (my $container = $unit->{garden_container}) {
        return svg_container_bin('Green lidded wheelie bin', 'wheelie', '#767472', '#41B28A', 1) if $container == $CONTAINERS{garden_240} || $container == $CONTAINERS{garden_140};
        return "";
    }

    my $container = $unit->{request_containers}[0] || 0;
    my $service_id = $unit->{service_id};
    if ($service_id eq 'bulky') {
        return "$base/bulky-black";
    }

    my $bag_blue_stripe = svg_container_sack('Blue striped sack', 'stripe', '#4f4cf0');
    my $bag_red_stripe = svg_container_sack('Red striped sack', 'stripe', '#E83651');
    my $bag_clear = svg_container_sack('Clear sack', 'normal', '#d8d8d8');
    my $wheelie_green = svg_container_bin('Green wheelie bin', "wheelie", '#41B28A');
    my $images = {
        $CONTAINERS{recycling_box} => "$base/box-green-mix",
        $CONTAINERS{recycling_240} => $wheelie_green,
        $CONTAINERS{recycling_blue_bag} => $bag_blue_stripe,
        $CONTAINERS{paper_bag} => $bag_clear,
        $CONTAINERS{refuse_bag} => $bag_red_stripe,
        $CONTAINERS{food_outdoor} => "$base/caddy-brown-large",

        $SERVICE_IDS{domestic_refuse} => svg_container_bin('Black wheelie bin', 'wheelie', '#333333'), # refuse
        $SERVICE_IDS{domestic_food} => "$base/caddy-brown-large", # food
        $SERVICE_IDS{domestic_paper} => svg_container_bin('Blue lidded wheelie bin', "wheelie", '#767472', '#00A6D2', 1), # paper and card
        $SERVICE_IDS{domestic_mixed} => $wheelie_green,
        $SERVICE_IDS{fas_refuse} => $bag_red_stripe,
        $SERVICE_IDS{communal_refuse} => svg_container_bin('Grey communal bin', 'communal', '#767472', '#333333'), # Communal refuse
        $SERVICE_IDS{fas_mixed} => $bag_blue_stripe,
        $SERVICE_IDS{communal_food} => svg_container_bin('Brown wheelie bin', 'wheelie', '#8B5E3D'), # Communal food
        $SERVICE_IDS{communal_paper} => svg_container_bin('Blue lidded grey communal bin', "communal", '#767472', '#00A6D2'), # Communal paper
        $SERVICE_IDS{communal_mixed} => svg_container_bin('Green communal bin', 'communal', '#41B28A'), # Communal recycling
        $SERVICE_IDS{fas_paper} => $bag_clear,
    };
    return $images->{$container} || $images->{$service_id};
}

sub waste_containers {
    my $self = shift;
    my $black_bins = $self->{c}->get_param('exchange') ? {
        $CONTAINERS{refuse_140} => 'Black rubbish bin (140L)',
        $CONTAINERS{refuse_240} => 'Black rubbish bin (240L)',
        $CONTAINERS{refuse_360} => 'Black rubbish bin (360L)',
        $CONTAINERS{refuse_180} => 'Black rubbish bin (180L)',
    } : {
        $CONTAINERS{refuse_140} => 'Black rubbish bin',
        $CONTAINERS{refuse_240} => 'Black rubbish bin',
        $CONTAINERS{refuse_360} => 'Black rubbish bin',
        $CONTAINERS{refuse_180} => 'Black rubbish bin',
    };
    return {
        %$black_bins,
        $CONTAINERS{refuse_bag} => 'Refuse Red Stripe Bag',
        $CONTAINERS{recycling_blue_bag} => 'Mixed Recycling Blue Striped Bag',
        $CONTAINERS{paper_bag} => 'Paper & Card Recycling Clear Bag',
        $CONTAINERS{refuse_1100} => 'Communal Refuse bin (1100L)',
        $CONTAINERS{recycling_1100} => 'Communal Recycling bin (1100L)',
        $CONTAINERS{food_240} => 'Communal Food bin (240L)',
        $CONTAINERS{paper_1100} => 'Communal Paper bin (1100L)',
        $CONTAINERS{recycling_240} => 'Green recycling bin (240L)',
        $CONTAINERS{recycling_360} => 'Green recycling bin (360L)',
        $CONTAINERS{recycling_box} => 'Green recycling box (55L)',
        $CONTAINERS{paper_240} => 'Blue lid paper and cardboard bin (240L)',
        $CONTAINERS{paper_360} => 'Blue lid paper and cardboard bin (360L)',
        $CONTAINERS{food_indoor} => 'Food waste bin (kitchen)',
        $CONTAINERS{food_outdoor} => 'Food waste bin (outdoor)',
        $CONTAINERS{paper_140} => 'Blue lid paper and cardboard bin (180L)',
        $CONTAINERS{garden_240} => 'Garden waste bin (240L)',
        $CONTAINERS{garden_140} => 'Garden waste bin (140L)',
        $CONTAINERS{garden_sack} => 'Garden waste sacks',
    };
}

=head2 service_name_override

Customer facing names for services

=cut

sub service_name_override {
    my ($self, $service) = @_;

    my %service_name_override = (
        $SERVICE_IDS{domestic_refuse} => 'Non-recyclable Refuse',
        $SERVICE_IDS{domestic_food} => 'Food waste',
        $SERVICE_IDS{domestic_paper} => 'Paper and card',
        $SERVICE_IDS{domestic_mixed} => 'Mixed recycling',
        $SERVICE_IDS{fas_refuse} => 'Non-recyclable Refuse',
        $SERVICE_IDS{communal_refuse} => 'Non-recyclable Refuse',
        $SERVICE_IDS{fas_mixed} => 'Mixed recycling',
        $SERVICE_IDS{garden} => 'Garden Waste',
        $SERVICE_IDS{communal_food} => 'Food waste',
        $SERVICE_IDS{communal_paper} => 'Paper and card',
        $SERVICE_IDS{communal_mixed} => 'Mixed recycling',
        $SERVICE_IDS{fas_paper} => 'Paper and card',
        $SERVICE_IDS{schedule2_mixed} => 'Mixed recycling',
        $SERVICE_IDS{schedule2_refuse} => 'Non-recyclable Refuse',
        $SERVICE_IDS{deliver_bags} => '',
    );

    return $service_name_override{$service->{ServiceId}} // '';
}

sub _waste_containers_no_request { return {
    $CONTAINERS{refuse_bag} => 1,
    $CONTAINERS{recycling_blue_bag} => 1,
    $CONTAINERS{paper_bag} => 1,
    $CONTAINERS{garden_sack} => 1,
} }

sub waste_request_single_radio_list { 0 }

=head2 bin_request_form_extra_fields

We want an extra message on the outdoor food container option.

=cut

sub bin_request_form_extra_fields {
    my ($self, $service, $id, $field_list) = @_;

    return unless $id == $CONTAINERS{food_outdoor};
    my %fields = @$field_list;
    $fields{"container-$id"}{option_hint} = 'Only three are allowed per property. Any more than this will not be collected.';
}

=head2 waste_munge_request_form_fields

If we're looking to change capacity, list the possibilities here.

=cut

sub waste_munge_request_form_fields {
    my ($self, $field_list) = @_;
    my $c = $self->{c};

    unless ($c->get_param('exchange')) {
        for (my $i=0; $i<@$field_list; $i+=2) {
            my ($key, $value) = ($field_list->[$i], $field_list->[$i+1]);
            next unless $key =~ /^container-(\d+)/;
            my $id = $1;
            if (my $cost = $self->container_cost($id)) {
                my $price = sprintf("£%.2f", $cost / 100);
                $price =~ s/\.00$//;
                $value->{option_hint} = "There is a $price cost for this container";
            }
        }
        return;
    }

    my @radio_options;
    for (my $i=0; $i<@$field_list; $i+=2) {
        my ($key, $value) = ($field_list->[$i], $field_list->[$i+1]);
        next unless $key =~ /^container-(\d+)/;
        my $id = $1;

        if (my $os = $c->get_param('override_size')) {
            $id = $CONTAINERS{refuse_180} if $os == '180';
            $id = $CONTAINERS{refuse_240} if $os == '240';
            $id = $CONTAINERS{refuse_360} if $os == '360';
        }

        if ($id == $CONTAINERS{refuse_180}) {
            $c->stash->{current_refuse_bin} = $id;
        } elsif ($id == $CONTAINERS{refuse_240}) {
            $c->stash->{current_refuse_bin} = $id;
            @radio_options = ( {
                value => $CONTAINERS{refuse_180},
                label => 'Smaller black rubbish bin',
                disabled => $value->{disabled},
                hint => 'You can decrease the size of your bin to 180L.',
            }, {
                value => $CONTAINERS{refuse_360},
                label => 'Larger black rubbish bin',
                disabled => $value->{disabled},
                hint => 'You already have the biggest sized bin allowed. If you have an exceptionally large household or your household has medical needs that create more waste than normal, you can apply for more capacity, but this will be assessed by our officers.',
            },
            );
        } elsif ($id == $CONTAINERS{refuse_360}) {
            $c->stash->{current_refuse_bin} = $id;
            @radio_options = ( {
                value => $CONTAINERS{refuse_180},
                label => '180L black rubbish bin ‘standard’',
                disabled => $value->{disabled},
            }, {
                value => $CONTAINERS{refuse_240},
                label => '240L black rubbish bin ‘larger’',
                disabled => $value->{disabled},
            },
            );
        }
    }

    @$field_list = (
        "container-capacity-change" => {
            type => 'Select',
            widget => 'RadioGroup',
            label => 'Which container do you need?',
            options => \@radio_options,
            required => 1,
        }
    );
}

=head2 waste_request_form_first_next

After picking a container, we ask what bins needs removing.

=cut

sub waste_request_form_first_title {
    my $self = shift;
    my $c = $self->{c};
    return 'Black bin size change request' if $c->get_param('exchange');
}

sub waste_request_form_first_next {
    my $self = shift;
    my $c = $self->{c};
    if ($c->get_param('exchange')) {
        my $uprn = $c->stash->{property}{uprn};
        return sub {
            my $data = shift;
            my $choice = $data->{"container-capacity-change"};
            if ($choice == $CONTAINERS{refuse_360}) {
                $c->res->redirect($c->stash->{waste_features}{large_refuse_application_form} . '?uprn=' . $uprn);
                $c->detach;
            } else {
                $self->waste_exchange_bin_setup_data($data, $choice);
            }
            return 'about_you';
        };
    }
    return 'removals';
}

# Set up container/quantity/removal for the form/summary page,
# but set replace to be used by the data munging
sub waste_exchange_bin_setup_data {
    my ($self, $data, $choice) = @_;
    my $c = $self->{c};
    my $bin = $c->stash->{current_refuse_bin};
    $data->{"container-$choice"} = 1;
    $data->{"quantity-$choice"} = 1;
    $data->{"replace-$choice"} = $bin;
    $data->{"container-$bin"} = 1;
    $data->{"removal-$bin"} = 1;
    $data->{"replace-$bin"} = -1; # So it is ignored
}

=head2 waste_munge_request_form_pages

We have a separate removal page, asking which bins need to be removed.

=cut

sub waste_munge_request_form_pages {
    my ($self, $page_list, $field_list) = @_;
    my $c = $self->{c};

    if (($c->stash->{current_refuse_bin} || 0) == $CONTAINERS{refuse_180}) {
        $c->stash->{first_page} = 'how_many_exchange';
    }

    my %maxes;
    foreach (@{$c->stash->{service_data}}) {
        next unless $_->{next} || $_->{request_only};
        my $containers = $_->{request_containers};
        my $maximum = $_->{request_max};
        foreach my $id (@$containers) {
            $maxes{$id} = ref $maximum ? $maximum->{$id} : $maximum;
        }
    }

    sub n { my $n = shift; my $w = ucfirst NUMWORDS($n); $w =~ s/Zero/None/; "$w ($n)"; }

    my @removal_options;
    for (my $i=0; $i<@$field_list; $i+=2) {
        my ($key, $value) = ($field_list->[$i], $field_list->[$i+1]);
        next unless $key =~ /^container-(\d+)/;
        my $id = $1;
        my $name = $c->stash->{containers}{$id};
        push @$field_list, "removal-$id" => {
            required => 1,
            type => 'Select',
            widget => 'RadioGroup',
            label => "$name: How many do you wish removing from your property?",
            tags => { small => 1 },
            options => [
                map { { value => $_, label => n($_) } } (0..$maxes{$id})
            ],
        };
        push @removal_options, "removal-$id";
    }

    push @$page_list, removals => {
        fields => [ @removal_options, 'submit' ],
        update_field_list => sub {
            my $form = shift;
            my $data = $form->saved_data;
            my $fields = {};
            foreach (@removal_options) {
                my ($id) = /removal-(.*)/;
                if ($data->{"container-$id"}) {
                    my $quantity = $data->{"quantity-$id"};
                    my $max = $quantity || $maxes{$id};
                    $fields->{$_}{options} = [
                        map { { value => $_, label => n($_) } } (0..$max)
                    ];
                } else {
                    $fields->{$_}{widget} = 'Hidden';
                    $fields->{$_}{required} = 0;
                }
            }
            # Both types of recycling container always
            if ($data->{'container-' . $CONTAINERS{recycling_240}} && $fields->{"removal-" . $CONTAINERS{recycling_box}}) {
                delete $fields->{"removal-" . $CONTAINERS{recycling_box}}{widget};
                delete $fields->{"removal-" . $CONTAINERS{recycling_box}}{required};
            }
            if ($data->{'container-' . $CONTAINERS{recycling_box}} && $fields->{"removal-" . $CONTAINERS{recycling_240}}) {
                delete $fields->{"removal-" . $CONTAINERS{recycling_240}}{widget};
                delete $fields->{"removal-" . $CONTAINERS{recycling_240}}{required};
            }
            return $fields;
        },
        title => 'How many containers need removing?',
        next => sub {
            # If it is a refuse bin, and they haven't asked for one to be
            # removed, we need to ask how many people live at the property
            for ($CONTAINERS{refuse_180}, $CONTAINERS{refuse_240}, $CONTAINERS{refuse_360}) {
                return 'how_many' if $_[0]->{"container-$_"} && !$_[0]->{"removal-$_"};
            }
            return 'about_you';
        },
    };
}

# Expand out everything to one entry per container
sub waste_munge_request_form_data {
    my ($self, $data) = @_;

    my $new_data;
    my @services = grep { /^container-/ } sort keys %$data;
    foreach (@services) {
        my ($id) = /container-(.*)/;
        my $quantity = $data->{"quantity-$id"} || 0;
        my $to_remove = $data->{"removal-$id"} || 0;
        next unless $data->{$_} || ($id == $CONTAINERS{recycling_240} || $id == $CONTAINERS{recycling_box});

        if (my $replace = $data->{"replace-$id"}) {
            if ($replace > -1) {
                $new_data->{"container-$id-exchange"} = $replace;
            }
        } elsif ($quantity - $to_remove > 0) {
            $new_data->{"container-$id-deliver-$_"} = 1
                for 1..($quantity-$to_remove);
            $new_data->{"container-$id-replace-$_"} = 1
                for 1..$to_remove;
        } elsif ($to_remove - $quantity > 0) {
            $new_data->{"container-$id-collect-$_"} = 1
                for 1..($to_remove-$quantity);
            $new_data->{"container-$id-replace-$_"} = 1
                for 1..$quantity;
        } else { # Equal
            $new_data->{"container-$id-replace-$_"} = 1
                for 1..$quantity;
        }
    }
    %$data = map { $_ => $data->{$_} } grep { !/^(container|quantity|removal)-/ } keys %$data;
    %$data = (%$data, %$new_data);
}

=head2 waste_munge_request_data

Get the right Echo data in place for container requests, including the action,
reason, container IDs and title.

=cut

sub waste_munge_request_data {
    my ($self, $id, $data, $form) = @_;

    my $c = $self->{c};
    my $address = $c->stash->{property}->{address};

    my ($container_id, $action, $n) = split /-/, $id;
    my $container = $c->stash->{containers}{$container_id};

    my ($action_id, $reason_id);
    if ($action eq 'deliver') {
        $action_id = 1; # Deliver
        $reason_id = 1; # Missing
    } elsif ($action eq 'collect') {
        $action_id = 2; # Remove
        $reason_id = 8; # Remove Containers
    } elsif ($action eq 'replace') {
        $action_id = '2::1'; # Replace
        $reason_id = 4; # Damaged
    } elsif ($action eq 'exchange') {
        # $container_id is the new bin
        $action_id = '2::1'; # Replace
        my $old_bin = $data->{"container-$id"};
        $reason_id = $old_bin < $container_id ? 9 : 10; # Increase/Reduce Capacity
    }

    if ($action eq 'deliver') {
        $data->{title} = "Request $container delivery";
    } elsif ($action eq 'replace' || $action eq 'exchange') {
        $data->{title} = "Request $container replacement";
    } else {
        $data->{title} = "Request $container collection";
    }
    $data->{detail} = $address;

    $c->set_param('Action', $action_id);
    $c->set_param('Reason', $reason_id);

    if ($data->{how_many} && $container =~ /rubbish bin/) { # Must be a refuse bin
        if ($data->{how_many} eq '5more') {
            $c->set_param('Container_Type', $CONTAINERS{refuse_240});
        } else {
            $c->set_param('Container_Type', $CONTAINERS{refuse_180});
        }
    } elsif ($action eq 'exchange') {
        my $old_bin = $data->{"container-$id"};
        $c->set_param('Container_Type', join("::", $old_bin, $container_id));
    } else {
        $c->set_param('Container_Type', $container_id);
    }

    my $service_id;
    my $services = $c->stash->{services};
    foreach my $s (keys %$services) {
        my $containers = $services->{$s}{request_containers};
        foreach (@$containers) {
            $service_id = $s if $_ eq $container_id;
        }
    }
    $service_id = $SERVICE_IDS{domestic_refuse} if !$service_id && $action eq 'exchange';
    $c->set_param('service_id', $service_id) if $service_id;

    if ($data->{payment}) {
        my $cost;
        if ($action ne 'collect') {
            if ($cost = $self->container_cost($container_id)) {
                $cost += $self->admin_fee_cost({quantity => 1, no_first_fee => $data->{first_bin_done}});
                $data->{first_bin_done} = 1;
            }
        }
        $c->set_param('payment', $cost || undef); # Want to undefine it if free
    }
}

sub _enquiry_nice_title {
    my $category = shift;
    if ($category eq 'Complaint against time') {
        $category = 'Issue with collection';
    } elsif ($category eq 'Failure to Deliver Bags/Containers') {
        $category = 'Issue with delivery';
    }
    return $category;
}

=head2 waste_munge_enquiry_data

Get the right data in place for the bin not returned / waste spillage / escalation categories.

=cut

sub waste_munge_enquiry_data {
    my ($self, $data) = @_;
    my $c = $self->{c};

    my $address = $c->stash->{property}->{address};

    $data->{title} = _enquiry_nice_title($data->{category});

    my $detail = "";
    if ($data->{category} eq 'Complaint against time') {
        my $event_id = $c->get_param('event_id');
        my ($echo, $ww) = split /:/, $event_id;
        $data->{extra_Notes} = "Originally Echo Event #$echo";
        $data->{extra_original_ref} = $ww;
        $data->{extra_missed_guid} = $c->get_param('event_guid');
    } elsif ($data->{category} eq 'Failure to Deliver Bags/Containers') {
        my $event_id = $c->get_param('event_id');
        my ($echo, $guid, $ww) = split /:/, $event_id;
        $data->{extra_Notes} = "Originally Echo Event #$echo";
        $data->{extra_original_ref} = $ww;
        $data->{extra_container_request_guid} = $guid;
    }
    $detail .= $self->service_name_override({ ServiceId => $data->{service_id} }) . "\n\n";
    $detail .= $address;

    $data->{detail} = $detail;
}

=head2 waste_escalation_target_days

Configure the number of days a containter escalation is expected to be resolved in.

=cut

sub waste_escalation_target_days { 5; }

=head2 waste_escalation_window

Configure when the escalation window for waste complaints starts/ends.

=cut

sub waste_escalation_window {
    my $start_days = 10; # Window starts on the 10th working day after the request was made
    my $window_days = 10; # Window ends a further 10 working days after the start date

    return ($start_days, $window_days);
}

=head2 container_cost / admin_fee_cost

Calculate how much, if anything, a request for a container should be.

=cut

sub container_cost {
    my ($self, $id) = @_;
    my $costs = WasteWorks::Costs->new({ cobrand => $self });
    my %id_to_name = reverse %CONTAINERS;
    return unless $id_to_name{$id};
    my $cost = $costs->get_cost('request_cost_' . $id_to_name{$id});
    return $cost;
}

sub admin_fee_cost {
    my ($self, $params) = @_;
    $params->{quantity} //= 1;
    my $costs = WasteWorks::Costs->new({ cobrand => $self });
    my $admin_fee = $costs->get_cost('request_cost_admin_fee') || 0;
    my $admin_fee_more = $costs->get_cost('request_cost_admin_fee_more') || 0;
    my $cost = $params->{no_first_fee} ? $admin_fee_more : $admin_fee;
    if ($params->{quantity} > 1) {
        $cost += $admin_fee_more * ($params->{quantity}-1);
    }
    return $cost;
}

=head2 Bulky waste collection

=over 4

=item * Collection is allowed for certain address types, including a domestic farm if it has a domestic refuse bin.

=cut

sub bulky_allowed_property {
    my ( $self, $property ) = @_;

    return if $property->{has_no_services};
    my $cfg = $self->feature('echo');

    my $type = $property->{type_id} || 0;
    my $valid_type = grep { $_ == $type } @{ $cfg->{bulky_address_types} || [] };
    my $domestic_farm = $type != 7 || $property->{domestic_refuse_bin};
    return $self->bulky_enabled && $valid_type && $domestic_farm;
}

=item * Kingston starts collections at 6:30am, and lets you cancel up until then.

=cut

sub bulky_collection_time { { hours => 6, minutes => 30 } }
sub bulky_cancellation_cutoff_time { { hours => 6, minutes => 30, days_before => 0 } }

=item * There is an 11pm cut-off for looking to book next day collections.

=cut

sub bulky_collection_window_start_date {
    my ($self, $now) = @_;
    my $start_date = $now->clone->truncate( to => 'day' )->add( days => 1 );
    # If past 11pm, push start date one day later
    if ($now->hour >= 23) {
        $start_date->add( days => 1 );
    }
    return $start_date;
}

=item * There is a custom prompt for the bulky location field

=back

=cut

sub bulky_location_text_prompt {
    "Please tell us where you will place the items for collection (include any access codes the crew will need)";
}

1;
