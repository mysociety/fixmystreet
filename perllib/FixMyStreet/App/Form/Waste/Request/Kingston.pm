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
            my $choice = $data->{'container-choice'};
            my $quantity = 1;
            my ($cost) = $c->cobrand->request_cost($choice, $quantity);
            $data->{payment} = $cost if $cost;
        }
    },
);

has_field submit => (
    type => 'Submit',
    value => 'Request container',
    element_attr => { class => 'govuk-button' },
    order => 999,
);

1;
