package FixMyStreet::Cobrand::Kingston;
use parent 'FixMyStreet::Cobrand::UKCouncils';

use utf8;
use Moo;
with 'FixMyStreet::Roles::Cobrand::Waste',
     'FixMyStreet::Roles::Cobrand::KingstonSutton',
     'FixMyStreet::Roles::Cobrand::SLWP',
     'FixMyStreet::Roles::Cobrand::SCP';

use Lingua::EN::Inflect qw( NUMWORDS );
use Hash::Util qw(lock_hash);

sub council_area_id { return 2480; }
sub council_area { return 'Kingston'; }
sub council_name { return 'Kingston upon Thames Council'; }
sub council_url { return 'kingston'; }
sub admin_user_domain { 'kingston.gov.uk' }

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

my %CONTAINERS = (
    refuse_140 => 1,
    refuse_180 => 35,
    refuse_240 => 2,
    refuse_360 => 3,
    recycling_box => 16,
    recycling_240 => 12,
    paper_240 => 19,
    paper_140 => 36,
    food_indoor => 23,
    food_outdoor => 24,
    garden_240 => 26,
    garden_140 => 27,
    garden_sack => 28,
);
lock_hash(%CONTAINERS);

sub waste_check_staff_payment_permissions {
    my $self = shift;
    my $c = $self->{c};

    return unless $c->stash->{is_staff};

    $c->stash->{staff_payments_allowed} = 'paye';
}

has lpi_value => ( is => 'ro', default => 'KINGSTON UPON THAMES' );

sub waste_payment_ref_council_code { "RBK" }

sub garden_collection_time { '6:30am' }

sub waste_quantity_max {
    return (
        $TASK_IDS{garden} => 5, # Garden waste maximum
    );
}

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
}

sub image_for_unit {
    my ($self, $unit) = @_;
    my $base = '/i/waste-containers';
    if (my $container = $unit->{garden_container}) {
        return svg_container_bin('wheelie', '#767472', '#41B28A', 1) if $container == $CONTAINERS{garden_240} || $container == $CONTAINERS{garden_140};
        return "";
    }

    if ($unit->{service_id} eq 'bulky') {
        return "$base/bulky-black";
    }

    # Base mixed recycling (2241) on the container itself
    my %containers = map { $_ => 1 } @{$unit->{request_containers}};
    return svg_container_bin("wheelie", '#41B28A') if $containers{$CONTAINERS{recycling_240}};
    return "$base/box-green-mix" if $containers{$CONTAINERS{recycling_box}};

    my $service_id = $unit->{service_id};
    my $images = {
        $TASK_IDS{domestic_refuse} => svg_container_bin('wheelie', '#333333'), # refuse
        $TASK_IDS{domestic_food} => "$base/caddy-brown-large", # food
        $TASK_IDS{domestic_paper} => svg_container_bin("wheelie", '#767472', '#00A6D2', 1), # paper and card
        $TASK_IDS{domestic_mixed} => svg_container_bin("wheelie", '#41B28A'), # dry mixed
        $TASK_IDS{domestic_refuse_bag} => svg_container_sack('stripe', '#E83651'), # domestic refuse bag
        $TASK_IDS{communal_refuse} => svg_container_bin('communal', '#767472', '#333333'), # Communal refuse
        $TASK_IDS{domestic_mixed_bag} => svg_container_sack('stripe', '#4f4cf0'), # domestic recycling bag
        $TASK_IDS{communal_food} => svg_container_bin('wheelie', '#8B5E3D'), # Communal food
        $TASK_IDS{communal_paper} => svg_container_bin("communal", '#767472', '#00A6D2'), # Communal paper
        $TASK_IDS{communal_mixed} => svg_container_bin('communal', '#41B28A'), # Communal recycling
        $TASK_IDS{domestic_paper_bag} => svg_container_sack('normal', '#d8d8d8'), # domestic paper bag
    };
    return $images->{$service_id};
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
        4 => 'Refuse Blue Sack',
        5 => 'Refuse Black Sack',
        6 => 'Refuse Red Stripe Bag',
        18 => 'Mixed Recycling Blue Striped Bag',
        29 => 'Recycling Single Use Bag',
        21 => 'Paper & Card Reusable Bag',
        22 => 'Paper Sacks',
        30 => 'Paper & Card Recycling Clear Bag',
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
        $CONTAINERS{recycling_240} => 'Recycling bin (240L)',
        13 => 'Recycling bin (360L)',
        20 => 'Paper recycling bin (360L)',
        31 => 'Paper 55L Box',
        $CONTAINERS{recycling_240} => 'Green recycling bin (240L)',
        13 => 'Green recycling bin (360L)',
        $CONTAINERS{recycling_box} => 'Green recycling box (55L)',
        $CONTAINERS{paper_240} => 'Blue lid paper and cardboard bin (240L)',
        20 => 'Blue lid paper and cardboard bin (360L)',
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
        $TASK_IDS{domestic_refuse} => 'Non-recyclable Refuse',
        $TASK_IDS{domestic_food} => 'Food waste',
        $TASK_IDS{domestic_paper} => 'Paper and card',
        $TASK_IDS{domestic_mixed} => 'Mixed recycling',
        $TASK_IDS{domestic_refuse_bag} => 'Non-recyclable Refuse',
        $TASK_IDS{communal_refuse} => 'Non-recyclable Refuse',
        $TASK_IDS{domestic_mixed_bag} => 'Mixed recycling',
        $TASK_IDS{garden} => 'Garden Waste',
        $TASK_IDS{communal_food} => 'Food waste',
        $TASK_IDS{communal_paper} => 'Paper and card',
        $TASK_IDS{communal_mixed} => 'Mixed recycling',
        $TASK_IDS{domestic_paper_bag} => 'Paper and card',
        $TASK_IDS{schedule2_mixed} => 'Mixed recycling',
        $TASK_IDS{schedule2_refuse} => 'Non-recyclable Refuse',
        $TASK_IDS{deliver_refuse_bags} => '',
        $TASK_IDS{deliver_recycling_bags} => '',
    );

    return $service_name_override{$service->{ServiceId}} // '';
}

=head2 garden_waste_renewal_cost_pa

The price change for a renewal is based upon the end
date of the subscription, not the current date.

=cut

sub garden_waste_renewal_cost_pa {
     my ($self, $end_date, $bin_count) = @_;
     $bin_count ||= 1;
     my $per_bin_cost = $self->_get_cost('ggw_cost_renewal', $end_date);
     my $cost = $per_bin_cost * $bin_count;
     return $cost;
}

sub garden_waste_renewal_sacks_cost_pa {
     my ($self, $end_date) = @_;
     return $self->_get_cost('ggw_sacks_cost_renewal', $end_date);
}

sub garden_waste_new_bin_admin_fee {
    my ($self, $new_bins) = @_;
    $new_bins ||= 0;

    my $per_new_bin_first_cost = $self->_get_cost('ggw_new_bin_first_cost');
    my $per_new_bin_cost = $self->_get_cost('ggw_new_bin_cost');

    my $cost = 0;
    if ($new_bins > 0) {
        $cost += $per_new_bin_first_cost;
        if ($new_bins > 1) {
            $cost += $per_new_bin_cost * ($new_bins - 1);
        }
    }
    return $cost;
}

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

    return unless $c->get_param('exchange');

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
            $c->stash->{current_refuse_bin} = 180;
        } elsif ($id == $CONTAINERS{refuse_240}) {
            $c->stash->{current_refuse_bin} = 240;
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
            $c->stash->{current_refuse_bin} = 360;
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
                $data->{"container-$choice"} = 1;
                $data->{"quantity-$choice"} = 1;
                $data->{"removal-$choice"} = 1;
            }
            return 'about_you';
        };
    }
    return 'removals';
}

=head2 waste_munge_request_form_pages

We have a separate removal page, asking which bins need to be removed.

=cut

sub waste_munge_request_form_pages {
    my ($self, $page_list, $field_list) = @_;
    my $c = $self->{c};

    if (($c->stash->{current_refuse_bin} || 0) == 180) {
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

        if ($quantity - $to_remove > 0) {
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

sub waste_munge_request_data {
    my ($self, $id, $data, $form) = @_;

    my $c = $self->{c};
    my $address = $c->stash->{property}->{address};

    my ($container_id, $action, $n) = split /-/, $id;
    my $container = $c->stash->{containers}{$container_id};

    my ($action_id, $reason_id);
    if ($action eq 'deliver') {
        $action_id = 1; # Deliver
        $reason_id = 1; # Missing (or 4 New)
    } elsif ($action eq 'collect') {
        $action_id = 2; # Collect
        $reason_id = 3; # Change capacity
    } elsif ($action eq 'replace') {
        $action_id = 3; # Replace
        $reason_id = $c->get_param('exchange') ? 3 : 2; # Change capacity : Damaged
    }

    if ($action eq 'deliver') {
        $data->{title} = "Request $container delivery";
    } elsif ($action eq 'replace') {
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
    } else {
        $c->set_param('Container_Type', $container_id);
    }

    if ($data->{payment}) {
        my $cost;
        if ($action ne 'collect') {
            ($cost) = $self->request_cost($container_id); # Will be full price, or nothing if free
            if ($cost) {
                if ($data->{first_bin_done}) {
                    $cost = $self->_get_cost('request_replace_cost_more') || $cost/2;
                } else {
                    $data->{first_bin_done} = 1;
                }
            }
        }
        $c->set_param('payment', $cost);
    }
}

=head2 request_cost

Calculate how much, if anything, a request for a container should be.

=cut

sub request_cost {
    my ($self, $id, $quantity, $containers) = @_;
    $quantity //= 1;
    if (my $cost = $self->_get_cost('request_replace_cost')) {
        my $cost_more = $self->_get_cost('request_replace_cost_more') || $cost/2;
        if ($quantity > 1) {
            $cost += $cost_more * ($quantity-1);
        }
        my $names = $self->{c}->stash->{containers};
        if ($names->{$id} !~ /bag|sack|food/i) {
            my $hint = "";
            return ($cost, $hint);
        }
    }
}

=head2 Bulky waste collection

Kingston starts collections at 6:30am, and lets you cancel up until then.

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

sub bulky_collection_time { { hours => 6, minutes => 30 } }
sub bulky_cancellation_cutoff_time { { hours => 6, minutes => 30, days_before => 0 } }

=head2 bulky_collection_window_start_date

K&S have an 11pm cut-off for looking to book next day collections.

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

1;
