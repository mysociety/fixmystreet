=head1 NAME

FixMyStreet::Roles::Cobrand::Waste - cobrand functions shared with all waste clients

=cut

package FixMyStreet::Roles::Cobrand::Waste;

use Moo::Role;
use Path::Tiny;

sub bin_payment_types {
    return {
        'csc' => 1,
        'credit_card' => 2,
        'direct_debit' => 3,
        'cheque' => 4,
        'waived' => 5,
        'cash' => 6,
    };
}

sub waste_subscription_types {
    return {
        New => 1,
        Renew => 2,
        Amend => 3,
        Transfer => 4,
    };
}

=head2 svg_container_sack

TYPE is either 'normal' or 'stripe'.

=cut

sub svg_container_sack {
    my ($title, $type, $colour) = @_;
    my $dir = path(FixMyStreet->path_to("web/i/waste-containers"));
    $type = ($type eq 'stripe') ? 'sack-stripe' : 'sack';
    my $data = $dir->child("$type.svg")->slurp_raw;
    $data =~ s{<title>.*?</title>}{<title>$title</title>};
    return {
        type => 'svg',
        data => $data,
        colour => $colour,
    };
}

=head2 svg_container_bin

TYPE is either 'wheelie' or 'communal'.

=cut

sub svg_container_bin {
    my ($title, $type, $colour_main, $colour_lid, $recycling_logo) = @_;
    my $dir = path(FixMyStreet->path_to("web/i/waste-containers"));
    my $data = $dir->child("$type.svg")->slurp_raw;
    $data =~ s{<title>.*?</title>}{<title>$title</title>};
    return {
        type => 'svg',
        data => $data,
        colour => $colour_main,
        lid_colour => $colour_lid,
        recycling_logo => $recycling_logo,
    };
}

sub svg_container_box {
    my ($title, $colour, $recycling_logo) = @_;
    my $dir = path(FixMyStreet->path_to("web/i/waste-containers"));
    my $data = $dir->child("box.svg")->slurp_raw;
    $data =~ s{<title>.*?</title>}{<title>$title</title>};
    return {
        type => 'svg',
        data => $data,
        colour => $colour,
        recycling_logo => $recycling_logo,
    };
}

=head2 waste_suggest_retry_on_no_property_data

Whether or not to show a page suggesting the user retries later
if we're not able to retrieve data for the property.

=cut

sub waste_suggest_retry_on_no_property_data { 0 }

# Garden related

sub garden_subscription_email_renew_reminder_opt_in { 0 }

sub waste_cheque_payments { 0 }

sub garden_hide_payment_method_field {
    my $self = shift;
    my $c = $self->{c};

    my $non_staff_no_dd = $c->stash->{waste_features}->{dd_disabled} && !$c->stash->{staff_payments_allowed};
    my $staff_no_choose = $c->stash->{staff_payments_allowed} && !$c->cobrand->waste_staff_choose_payment_method;
    return $non_staff_no_dd || $staff_no_choose;
}

=head2 waste_sub_due

Returns true/false if now is after garden_due_date.

=cut

sub waste_sub_due {
    my ($self, $date) = @_;

    my $now = DateTime->now->set_time_zone(FixMyStreet->local_time_zone);
    my $sub_end = DateTime::Format::W3CDTF->parse_datetime($date);
    my $due_date = $self->garden_due_date($sub_end->truncate(to => 'day'));
    return $now >= $due_date;
}

=head2 waste_show_cancel_request

Show the option to cancel a request for all users, if the report hasn't
already been cancelled.

Enabled if 'request_cancel_enabled' is set.

=cut

sub waste_show_cancel_request {
    my ($self, $request_report) = @_;

    my $c = $self->{c};
    return unless $c->stash->{waste_features}->{request_cancel_enabled};

    return $request_report->state ne 'cancelled';
}

=head2 waste_can_cancel_request


Allows cancelling a request if the user is staff or the person that
made the request, and the report is not already cancelled.

Enabled if 'request_cancel_enabled' is set.

=cut

sub waste_can_cancel_request {
    my ($self, $request_report) = @_;

    return unless $self->waste_show_cancel_request($request_report);

    # Staff members and the person who made the request can cancel it.
    my $c = $self->{c};
    return $c->user->is_superuser ||
        $c->user->belongs_to_body($self->body->id) ||
        $c->user->id == $request_report->user_id;
}

1;
