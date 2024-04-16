package FixMyStreet::Cobrand::Sutton;
use parent 'FixMyStreet::Cobrand::UKCouncils';

use utf8;
use Moo;
with 'FixMyStreet::Roles::CobrandSLWP';
with 'FixMyStreet::Roles::SCP';

use Digest::SHA qw(sha1_hex);
use Encode qw(encode_utf8);

sub council_area_id { return 2498; }
sub council_area { return 'Sutton'; }
sub council_name { return 'Sutton Council'; }
sub council_url { return 'sutton'; }
sub admin_user_domain { 'sutton.gov.uk' }

use constant CONTAINER_REFUSE_140 => 1;
use constant CONTAINER_REFUSE_240 => 2;
use constant CONTAINER_REFUSE_360 => 3;
use constant CONTAINER_PAPER_BIN => 19;

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
        return "$base/bin-green-brown-lid" if $container == 26 || $container == 27;
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
        return "$base/bin-brown";
    }
    my $images = {
        2238 => "$base/bin-brown", # refuse
        2239 => "$base/caddy-brown-large", # food
        2240 => "$base/bin-green", # paper and card
        2241 => "$base/box-green-mix", # dry mixed
        2242 => "$base/sack-clear-red", # domestic refuse bag
        2243 => "$base/large-communal-grey-black-lid", # Communal refuse
        2246 => "$base/sack-clear-blue", # domestic recycling bag
        2248 => "$base/bin-brown", # Communal food
        2249 => "$base/bin-grey-blue-lid-recycling", # Communal paper
        2250 => "$base/large-communal-green", # Communal recycling
        2632 => "$base/sack-clear", # domestic paper bag
    };
    return $images->{$service_id};
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

=head2 request_cost

Calculate how much, if anything, a request for a container should be.

=cut

sub request_cost {
    my ($self, $id, $containers) = @_;
    if (my $cost = $self->_get_cost('request_change_cost')) {
        foreach (CONTAINER_REFUSE_140, CONTAINER_REFUSE_240, CONTAINER_PAPER_BIN) {
            if ($id == $_ && !$containers->{$_}) {
                my $price = sprintf("£%.2f", $cost / 100);
                $price =~ s/\.00$//;
                my $hint = "There is a $price administration/delivery charge to change the size of your container";
                return ($cost, $hint);
            }
        }
    }
    if (my $cost = $self->_get_cost('request_replace_cost')) {
        foreach (CONTAINER_REFUSE_140, CONTAINER_REFUSE_240, CONTAINER_REFUSE_360, CONTAINER_PAPER_BIN) {
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
