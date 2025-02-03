package FixMyStreet::Cobrand::Sutton;
use parent 'FixMyStreet::Cobrand::UKCouncils';

use utf8;
use Moo;
with 'FixMyStreet::Roles::Cobrand::Waste',
     'FixMyStreet::Roles::Cobrand::KingstonSutton',
     'FixMyStreet::Roles::Cobrand::SCP';

use Digest::SHA qw(sha1_hex);
use Encode qw(encode_utf8);
use Hash::Util qw(lock_hash);

sub council_area_id { return 2498; }
sub council_area { return 'Sutton'; }
sub council_name { return 'Sutton Council'; }
sub council_url { return 'sutton'; }
sub admin_user_domain { 'sutton.gov.uk' }

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
    refuse_240 => 2,
    refuse_360 => 3,
    paper_240 => 19,
    paper_140 => 36,
    recycling_blue_bag => 18,
    paper_bag => 30,
);
lock_hash(%CONTAINERS);

=head2 waste_on_the_day_criteria

If it's before 6pm on the day of collection, treat an Outstanding/Allocated
task as if it's the next collection and in progress, do not allow missed
collection reporting, and do not show the collected time.

=cut

sub waste_on_the_day_criteria {
    my ($self, $completed, $state, $now, $row) = @_;

    return unless $now->hour < 18;
    if ($state eq 'Outstanding' || $state eq 'Allocated') {
        $row->{next} = $row->{last};
        $row->{next}{state} = 'In progress';
        delete $row->{last};
    }
    $row->{report_allowed} = 0; # No reports pre-6pm, completed or not
    if ($row->{last}) {
        # Prevent showing collected time until reporting is allowed
        $row->{last}{completed} = 0;
    }
}

sub waste_check_staff_payment_permissions {
    my $self = shift;
    my $c = $self->{c};

    return unless $c->stash->{is_staff};

    $c->stash->{staff_payments_allowed} = 'paye';
}

has lpi_value => ( is => 'ro', default => 'SUTTON' );

sub waste_payment_ref_council_code { "LBS" }

sub garden_collection_time { '6am' }

sub waste_garden_allow_cancellation { 'staff' }

sub image_for_unit {
    my ($self, $unit) = @_;
    my $base = '/i/waste-containers';
    if (my $container = $unit->{garden_container}) {
        return svg_container_bin("wheelie", '#41B28A', '#8B5E3D') if $container == 26 || $container == 27;
        return svg_container_sack('normal', '#F5F5DC') if $container == 28; # Garden waste sack
        return "";
    }
    if (my $container = $unit->{request_containers}[0]) {
        return "$base/caddy-brown-large" if $container == 24;
    }
    my $service_id = $unit->{service_id};
    if ($service_id eq 'bulky') {
        return "$base/bulky-black";
    }
    if ($service_id == 2243 && $unit->{schedule} =~ /fortnight/i) {
        # Communal fortnightly is a wheelie bin, not a large bin
        return svg_container_bin('wheelie', '#8B5E3D');
    }
    my $images = {
        $TASK_IDS{domestic_refuse} => svg_container_bin('wheelie', '#8B5E3D'),
        $TASK_IDS{domestic_food} => "$base/caddy-brown-large",
        $TASK_IDS{domestic_paper} => svg_container_bin('wheelie', '#41B28A'),
        $TASK_IDS{domestic_mixed} => "$base/box-green-mix",
        $TASK_IDS{domestic_refuse_bag} => svg_container_sack('stripe', '#E83651'),
        $TASK_IDS{communal_refuse} => svg_container_bin('communal', '#767472', '#333333'),
        $TASK_IDS{domestic_mixed_bag} => svg_container_sack('stripe', '#4f4cf0'),
        $TASK_IDS{communal_food} => svg_container_bin('wheelie', '#8B5E3D'),
        $TASK_IDS{communal_paper} => svg_container_bin("wheelie", '#767472', '#00A6D2', 1),
        $TASK_IDS{communal_mixed} => svg_container_bin('communal', '#41B28A'),
        $TASK_IDS{domestic_paper_bag} => svg_container_sack('normal', '#d8d8d8'),
    };
    return $images->{$service_id};
}

=head2 service_name_override

Customer facing names for services

=cut

sub service_name_override {
    my ($self, $service) = @_;

    my %service_name_override = (
        $TASK_IDS{domestic_refuse} => 'Non-Recyclable Refuse',
        $TASK_IDS{domestic_food} => 'Food Waste',
        $TASK_IDS{domestic_paper} => 'Paper & Card',
        $TASK_IDS{domestic_mixed} => 'Mixed Recycling (Cans, Plastics & Glass)',
        $TASK_IDS{domestic_refuse_bag} => 'Non-Recyclable Refuse',
        $TASK_IDS{communal_refuse} => 'Non-Recyclable Refuse',
        $TASK_IDS{domestic_mixed_bag} => 'Mixed Recycling (Cans, Plastics & Glass)',
        $TASK_IDS{garden} => 'Garden Waste',
        $TASK_IDS{communal_food} => 'Food Waste',
        $TASK_IDS{communal_paper} => 'Paper & Card',
        $TASK_IDS{communal_mixed} => 'Mixed Recycling (Cans, Plastics & Glass)',
        $TASK_IDS{domestic_paper_bag} => 'Paper & Card',
        $TASK_IDS{schedule2_mixed} => 'Mixed Recycling (Cans, Plastics & Glass)',
        $TASK_IDS{schedule2_refuse} => 'Non-Recyclable Refuse',
        $TASK_IDS{deliver_refuse_bags} => '',
        $TASK_IDS{deliver_recycling_bags} => '',
    );

    return $service_name_override{$service->{ServiceId}} // '';
}

sub waste_cc_munge_form_details {
    my ($self, $c) = @_;

    $c->stash->{payment_amount} = $c->stash->{amount} * 100;

    my $url = $c->uri_for_action(
        '/waste/pay_complete', [
            $c->stash->{report}->id,
            $c->stash->{report}->get_extra_metadata('redirect_id')
        ]);

    $c->stash->{redirect_url} = $url;

    my ($pspid, $sha_passphrase);
    if ($c->stash->{report}->category eq 'Bulky collection') {
        $sha_passphrase = $c->stash->{payment_details}->{sha_passphrase_bulky};
        $pspid = $c->stash->{payment_details}->{pspid_bulky};
    } else {
        $sha_passphrase = $c->stash->{payment_details}->{sha_passphrase};
        $pspid = $c->stash->{payment_details}->{pspid};
    }
    $c->stash->{pspid} = $pspid;

    my $form_params = {
        'PSPID' => $pspid,
        'ORDERID' => $c->stash->{reference},
        'AMOUNT' => $c->stash->{payment_amount},
        'CURRENCY' => 'GBP',
        'LANGUAGE' => 'en_GB',
        'CN' => $c->stash->{first_name} . " " . $c->stash->{last_name},
        'EMAIL' => $c->stash->{email},
        'OWNERZIP' => $c->stash->{postcode},
        'OWNERADDRESS' => $c->stash->{address1},
        'OWNERCTY' => 'UK',
        'OWNERTOWN' => $c->stash->{town},
        'OWNERTELNO' => $c->stash->{phone},
        'ACCEPTURL' => $url,
        'DECLINEURL' => $url,
        'EXCEPTIONURL' => $url,
        'CANCELURL' => $url,
    };

    my $sha = $self->garden_waste_generate_sig( $form_params, $sha_passphrase );
    $c->stash->{cc_sha} = $sha;
}

sub garden_waste_generate_sig {
    my ($self, $params, $passphrase) = @_;

    my $str = "";
    for my $param ( sort { uc($a) cmp uc($b) } keys %$params ) {
        next unless defined $params->{$param} && length $params->{$param}; # Want any 0s
        $str .= uc($param) . "=" . encode_utf8($params->{$param}) . $passphrase;
    }

    my $sha = sha1_hex( $str );
    return uc $sha;
}

sub waste_cc_has_redirect {
    my ($self, $p) = @_;
    return 1 if $p->category eq 'Request new container';
    return 0;
}

around garden_cc_check_payment_status => sub {
    my ($orig, $self, $c, $p) = @_;

    if ($p->category eq 'Request new container') {
        # Call the SCP role code
        return $self->$orig($c, $p);
    }

    # Otherwise, the EPDQ code

    my $passphrase;
    if ($p->category eq 'Bulky collection') {
        $passphrase = $self->feature('payment_gateway')->{sha_out_passphrase_bulky};
    } else {
        $passphrase = $self->feature('payment_gateway')->{sha_out_passphrase};
    }

    if ( $passphrase ) {
        my $sha = $c->get_param('SHASIGN');

        my %params = %{$c->req->params};
        delete $params{SHASIGN};
        my $check = $self->garden_waste_generate_sig( \%params, $passphrase );
        if ( $check ne $sha ) {
            $c->stash->{error} = "Failed security check";
            return undef;
        }
    }

    my $status = $c->get_param('STATUS');
    if ( $status == 9 ) {
        return $c->get_param('PAYID');
    } else {
        my $error = "Unknown error";
        if ( $status == 1 ) {
            $error = "Payment cancelled";
        } elsif ( $status == 2 ) {
            $error = "Payment declined";
        }
        $c->stash->{error} = $error;
        return undef;
    }
};

sub waste_request_single_radio_list { 1 }

=head2 waste_munge_request_form_fields

Replace the usual checkboxes grouped by service with one radio list of
containers.

=cut

sub waste_munge_request_form_fields {
    my ($self, $field_list) = @_;
    my $c = $self->{c};

    my @radio_options;
    my @replace_options;
    my $costs = WasteWorks::Costs->new({ cobrand => $self });
    my $change_cost = $costs->get_cost('request_change_cost');
    for (my $i=0; $i<@$field_list; $i+=2) {
        my ($key, $value) = ($field_list->[$i], $field_list->[$i+1]);
        next unless $key =~ /^container-(\d+)/;
        my $id = $1;

        my ($cost, $hint) = $self->request_cost($id, 1, $c->stash->{quantities});

        my $data = {
            value => $id,
            label => $self->{c}->stash->{containers}->{$id},
            disabled => $value->{disabled},
            $hint ? (hint => $hint) : (),
        };
        if ($cost && $change_cost && $cost == $change_cost) {
            push @replace_options, $data;
        } else {
            push @radio_options, $data;
        }
    }

    if (@replace_options) {
        $radio_options[0]{tags}{divider_template} = "waste/request/intro_replace";
        $replace_options[0]{tags}{divider_template} = "waste/request/intro_change";
        push @radio_options, @replace_options;
    }

    @$field_list = (
        "container-choice" => {
            type => 'Select',
            widget => 'RadioGroup',
            label => 'Which container do you need?',
            options => \@radio_options,
            required => 1,
        }
    );
}

=head2 waste_request_form_first_next

After picking a container, we jump straight to the about you page if they've
picked a bag or changing size; otherwise we move to asking for a reason.

=cut

sub waste_request_form_first_title { 'Which container do you need?' }
sub waste_request_form_first_next {
    my $self = shift;
    my $containers = $self->{c}->stash->{quantities};
    return sub {
        my $data = shift;
        my $choice = $data->{"container-choice"};
        return 'about_you' if $choice == $CONTAINERS{recycling_blue_bag} || $choice == $CONTAINERS{paper_bag};
        foreach ($CONTAINERS{refuse_140}, $CONTAINERS{refuse_240}, $CONTAINERS{paper_240}) {
            if ($choice == $_ && !$containers->{$_}) {
                $data->{request_reason} = 'change_capacity';
                return 'about_you';
            }
        }
        return 'replacement';
    };
}

# Take the chosen container and munge it into the normal data format
sub waste_munge_request_form_data {
    my ($self, $data) = @_;
    my $container_id = delete $data->{'container-choice'};
    $data->{"container-$container_id"} = 1;
}

sub waste_munge_request_data {
    my ($self, $id, $data, $form) = @_;

    my $c = $self->{c};
    my $address = $c->stash->{property}->{address};
    my $container = $c->stash->{containers}{$id};
    my $quantity = 1;
    my $reason = $data->{request_reason} || '';
    my $nice_reason = $c->stash->{label_for_field}->($form, 'request_reason', $reason);

    my ($action_id, $reason_id);
    if ($reason eq 'damaged') {
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
    } elsif ($reason eq 'change_capacity') {
        $action_id = '2::1';
        $reason_id = '3::3';
        if ($id == $CONTAINERS{refuse_140}) {
            $id = $CONTAINERS{refuse_240} . '::' . $CONTAINERS{refuse_140};
        } elsif ($id == $CONTAINERS{refuse_240}) {
            if ($c->stash->{quantities}{+$CONTAINERS{refuse_360}}) {
                $id = $CONTAINERS{refuse_360} . '::' . $CONTAINERS{refuse_240};
            } else {
                $id = $CONTAINERS{refuse_140} . '::' . $CONTAINERS{refuse_240};
            }
        } elsif ($id == $CONTAINERS{paper_240}) {
            $id = $CONTAINERS{paper_140} . '::' . $CONTAINERS{paper_240};
        }
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

    $c->set_param('Action', join('::', ($action_id) x $quantity));
    $c->set_param('Reason', join('::', ($reason_id) x $quantity));
    $c->set_param('Container_Type', $id);
}

=head2 request_cost

Calculate how much, if anything, a request for a container should be.
Quantity doesn't matter here.

=cut

sub request_cost {
    my ($self, $id, $quantity, $containers) = @_;
    my $costs = WasteWorks::Costs->new({ cobrand => $self });
    if (my $cost = $costs->get_cost('request_change_cost')) {
        foreach ($CONTAINERS{refuse_140}, $CONTAINERS{refuse_240}, $CONTAINERS{paper_240}) {
            if ($id == $_ && !$containers->{$_}) {
                my $price = sprintf("£%.2f", $cost / 100);
                $price =~ s/\.00$//;
                my $hint = "There is a $price administration/delivery charge to change the size of your container";
                return ($cost, $hint);
            }
        }
    }
    if (my $cost = $costs->get_cost('request_replace_cost')) {
        foreach ($CONTAINERS{refuse_140}, $CONTAINERS{refuse_240}, $CONTAINERS{refuse_360}, $CONTAINERS{paper_240}) {
            if ($id == $_ && $containers->{$_}) {
                my $price = sprintf("£%.2f", $cost / 100);
                $price =~ s/\.00$//;
                my $hint = "There is a $price administration/delivery charge to replace your container";
                return ($cost, $hint);
            }
        }
    }
}

=head2 Bulky waste collection

Sutton starts collections at 6am, and lets you cancel up until 6am.

=cut

sub bulky_collection_time { { hours => 6, minutes => 0 } }
sub bulky_cancellation_cutoff_time { { hours => 6, minutes => 0, days_before => 0 } }

1;
