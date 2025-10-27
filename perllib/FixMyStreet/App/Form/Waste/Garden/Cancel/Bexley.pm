package FixMyStreet::App::Form::Waste::Garden::Cancel::Bexley;

use utf8;

use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste::Garden::Cancel::Shared';

with 'FixMyStreet::App::Form::Waste::Garden::Verify::Bexley';

has_page customer_reference => (
    customer_reference(
        continue_field        => 'continue',
        next_page_if_verified => 'reason',
    )
);

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
    tags    => { initial_hidden => 1 },
);

has_page verify_failed => ( verify_failed() );

has_page confirm => (
    intro => 'garden/cancel_tandc.html',
    title => 'Cancel your garden waste subscription',
    fields => ['confirm_tandc', 'submit'],
    finished => sub {
        return $_[0]->wizard_finished('process_garden_cancellation');
    },
    next => 'done',
);

has_field confirm_tandc => (
    type => 'Checkbox',
    option_label => 'I agree to the terms and conditions',
    required => 1,
    label => '',
    order => 998,
);

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

    return map {
        {   label => $_,
            value => $_,
            (   $_ eq 'Other'
                ? ( data_show => '#form-reason_further_details-row' )
                : ( data_hide => '#form-reason_further_details-row' )
            ),
        }
    } @options;
}

1;
