package FixMyStreet::App::Form::Licence::Fields::TemporaryProhibition;

use utf8;
use HTML::FormHandler::Moose::Role;

=head1 NAME

FixMyStreet::App::Form::Licence::Fields::TemporaryProhibition - Temporary prohibition fields for licence forms

=head1 DESCRIPTION

Provides temporary traffic prohibition fields used by all TfL licence forms:
parking_bay_suspension, road_closure_required, terms_accepted

These fields are identical across all 16 licence types.

=cut

has_field parking_bay_suspension => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Will a parking, loading, disabled and/or motorcycle parking bay need to be suspended?',
    required => 1,
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
        { label => 'N/A', value => 'N/A' },
    ],
);

has_field road_closure_required => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Will a road closure be required?',
    required => 1,
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
        { label => 'N/A', value => 'N/A' },
    ],
);

has_field terms_accepted => (
    type => 'Checkbox',
    label => 'Terms and Conditions',
    required => 1,
    option_label => 'I confirm that I have read and understood the Highway licensing policy and Standard conditions for highways consents, and that I am the applicant applying for this licence',
);

1;
