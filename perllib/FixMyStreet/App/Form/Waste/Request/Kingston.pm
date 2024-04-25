=head1 NAME

FixMyStreet::App::Form::Waste::Request::Kingston - Kingston-specific request new container form

=head1 SYNOPSIS

The Kingston container request form lets you request one container at a time
(code for that in L<FixMyStreet::Roles::CobrandSLWP>).

=head1 PAGES

=cut

package FixMyStreet::App::Form::Waste::Request::Kingston;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste::Request';

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
            my $total_paid_quantity = 0;
            foreach (@services) {
                my ($id) = /container-(.*)/;
                my $quantity = $data->{"quantity-$id"};
                my $names = $c->stash->{containers};
                if ($names->{$id} !~ /bag|sack|food/i) {
                    $total_paid_quantity += $quantity;
                }
            }
            return unless $total_paid_quantity;
            my ($cost) = $c->cobrand->request_cost(1, $total_paid_quantity);
            $data->{payment} = $cost if $cost;
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

has_field submit => (
    type => 'Submit',
    value => 'Request containers',
    element_attr => { class => 'govuk-button' },
    order => 999,
);

1;
