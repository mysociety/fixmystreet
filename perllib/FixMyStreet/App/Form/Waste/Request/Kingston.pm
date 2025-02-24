=head1 NAME

FixMyStreet::App::Form::Waste::Request::Kingston - Kingston-specific request new container form

=head1 SYNOPSIS

The Kingston container request form lets you request multiple containers,
or change size of your refuse container (code for that in
L<FixMyStreet::Cobrand::Kingston>).

=head1 PAGES

=cut

package FixMyStreet::App::Form::Waste::Request::Kingston;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste::Request';

use constant CONTAINER_REFUSE_240 => 3;

=head2 About you

At the last step of the form, the user is asked for their personal details.

=cut

has_page about_you => (
    fields => ['name', 'email', 'phone', 'continue'],
    intro => 'about_you.html',
    title => 'About you',
    next => 'summary',
    post_process => sub {
        my $form = shift;
        my $data = $form->saved_data;
        my $c = $form->c;
        if ($data) {
            my @services = grep { /^container-\d/ && $data->{$_} } sort keys %$data;
            my $total = 0;
            my $first_admin_fee;
            foreach (@services) {
                my ($id) = /container-(.*)/;
                my $quantity = $data->{"quantity-$id"} or next;
                if (my $cost = $c->cobrand->container_cost($id)) {
                    $total += $cost * $quantity;
                    $total += $c->cobrand->admin_fee_cost({quantity => $quantity, no_first_fee => $first_admin_fee});
                    $first_admin_fee = 1;
                }
            }
            $data->{payment} = $total if $total;
        }
    },
);

has_page how_many => (
    fields => ['how_many', 'continue'],
    title => 'Reason for request',
    next => 'about_you',
);

has_field how_many => (
    required => 1,
    type => 'Select',
    widget => 'RadioGroup',
    label => 'How many people live in this household?',
    options => [
        { value => 'less5', label => '1 to 4' },
        { value => '5more', label => '5 or more' },
    ],
);

has_page how_many_exchange => (
    fields => ['how_many_exchange', 'continue'],
    title => 'Black bin size change request',
    intro => 'request/intro.html',
    post_process => sub {
        my $form = shift;
        my $data = $form->saved_data;
        if ($data) {
            my $how_many = $data->{"how_many_exchange"} || '';
            return if $how_many eq 'less5' || $how_many eq '7more';
            $form->c->cobrand->waste_exchange_bin_setup_data($data, CONTAINER_REFUSE_240);
        }
    },
    next => sub {
        my $data = shift;
        my $how_many = $data->{"how_many_exchange"};
        if ($how_many eq 'less5' || $how_many eq '7more') {
            return 'biggest_bin_allowed';
        }
        return 'about_you';
    },
);

has_field how_many_exchange => (
    required => 1,
    type => 'Select',
    widget => 'RadioGroup',
    label => 'How many people live in this household?',
    options => [
        { value => 'less5', label => '1 to 4' },
        { value => '5or6', label => '5 or 6' },
        { value => '7more', label => '7 or more' },
    ],
);

has_page biggest_bin_allowed => (
    fields => [],
    template => 'waste/biggest_bin_allowed.html',
);

has_field submit => (
    type => 'Submit',
    value => 'Request containers',
    element_attr => { class => 'govuk-button' },
    order => 999,
);

1;
