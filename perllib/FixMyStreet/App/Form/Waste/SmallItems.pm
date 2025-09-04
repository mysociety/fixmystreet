package FixMyStreet::App::Form::Waste::SmallItems;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste::Bulky::Shared';

has small_items => ( is => 'ro', default => 1 );

has_page intro => (
    title => 'Book small items collection',
    intro => 'small_items/intro.html',
    fields => ['continue'],
    next => 'about_you',
);

has_page about_you => (
    fields => ['name', 'email', 'phone', 'continue'],
    title => 'About you',
    next => 'choose_date_earlier',
);

with 'FixMyStreet::App::Form::Waste::AboutYou';

has_field submit => (
    type => 'Submit',
    value => 'Submit booking',
    element_attr => { class => 'govuk-button' },
    order => 999,
);

=head2 items_sort_key

Brent sorts the items by ID so that we can manually set the ordering in the admin.

=cut

sub _build_items_sort_key {
    return 'bartec_id' if $_[0]->c->cobrand->moniker eq 'brent';
    return 'name';
}

has items_master_list_hook => ( is => 'ro', default => 'small_items_master_list' );

sub _build_items_extra {
    shift->c->cobrand->small_items_extra;
}

1;
