package FixMyStreet::App::Form::Waste::Garden::Cancel::Bexley;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste::Garden::Cancel';

with 'FixMyStreet::App::Form::Waste::Garden::AboutYou::Bexley';

has_page about_you =>
    ( about_you( continue_field => 'continue', next_page => 'reason' ) );

has_page reason => (
    title => 'Reason for cancellation',
    fields => [ 'reason', 'reason_further_details', 'continue' ],
    next => 'confirm',
);

has_page confirm => remove_about_you_fields(
    FixMyStreet::App::Form::Waste::Garden::Cancel::intro() );

has_field continue => (
    type => 'Submit',
    value => 'Continue',
    element_attr => { class => 'govuk-button' },
    order => 999,
);

has_field reason => (
    type => 'Select',
    widget => 'RadioGroup',
    required => 1,
    label => 'Reason for cancellation',
    messages => { required => 'Please select a reason' },
);

sub options_reason {
    my $form = shift;

    my @options = (
        'Price',
        'Service issues',
        'Moving out of borough',
        'Other',
    );
    return map { { label => $_, value => $_ } } @options;
}

has_field reason_further_details => (
    type => 'Text',
    widget => 'Textarea',
    label =>
        "If you selected 'Other', please provide further details (up to 250 characters)",
    required_when => { reason => 'Other' },
    maxlength => 250,
    messages => { required => 'Please provide further details' },
);

1;
