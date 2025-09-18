package FixMyStreet::App::Form::Waste::Garden::Cancel::Bexley;

use utf8;

use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste::Garden::Cancel::Shared';

with 'FixMyStreet::App::Form::Waste::Garden::Verify::Bexley';

has_page customer_reference =>
    ( customer_reference( continue_field => 'continue' ) );

has_page about_you =>
    ( about_you( continue_field => 'continue', next_page => 'reason' ) );

has_page reason => (
    title => 'Reason for cancellation',
    fields => [ 'reason', 'reason_further_details', 'continue' ],
    next => 'confirm',
);

has_field reason => (
    type => 'Select',
    widget => 'RadioGroup',
    required => 1,
    label => 'Reason for cancellation',
    messages => { required => 'Please select a reason' },
);

has_field reason_further_details => (
    type => 'Text',
    widget => 'Textarea',
    label =>
        "If you selected 'Other', please provide further details (up to 250 characters)",
    required_when => { reason => 'Other' },
    maxlength => 250,
    messages => { required => 'Please provide further details' },
);

has_page confirm =>
    FixMyStreet::App::Form::Waste::Garden::Cancel::Shared::intro();

has_field continue => (
    type => 'Submit',
    value => 'Continue',
    element_attr => { class => 'govuk-button' },
    order => 999,
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

1;
