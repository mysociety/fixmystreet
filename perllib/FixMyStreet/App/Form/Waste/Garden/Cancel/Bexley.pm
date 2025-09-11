package FixMyStreet::App::Form::Waste::Garden::Cancel::Bexley;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste::Garden::Cancel';

has_page about_you => (
    fields => ['name', 'phone', 'email', 'continue'],
    title => 'About you',
    next => 'reason',
);

has_page reason => (
    title => 'Reason for cancellation',
    fields => [ 'reason', 'reason_further_details', 'continue' ],
    next => 'confirm',
);

sub confirm {
    my %defaults = FixMyStreet::App::Form::Waste::Garden::Cancel::intro();
    my @fields = grep { $_ !~ /^(name|phone|email)$/ } @{ $defaults{fields} };
    $defaults{fields} = \@fields;
    return %defaults;
}

has_page confirm => ( confirm() );

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
