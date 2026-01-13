package FixMyStreet::App::Form::Licence::Fields::Electrical;

use utf8;
use HTML::FormHandler::Moose::Role;

=head1 NAME

FixMyStreet::App::Form::Licence::Fields::Electrical - Electrical fields for licence forms

=head1 DESCRIPTION

Provides questions regarding electricity for certain TfL licence forms
(Lights in Trees, Festive, Column attachments). Fields are:
enough_space
power_supply
mpan_number
electrical_information

=cut

has_field enough_space => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Have you confirmed on-site that there is enough space for the required equipment?',
    required => 1,
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

has_field power_supply => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Does this installation require an electrical power supply?',
    required => 1,
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

has_field mpan_number => (
    type => 'Text',
    label => 'If this installation will draw electricity, please provide the MPAN (Meter Point Administration Number)',
    tags => {
        hint => 'You must provide electrical design documentation as set out in the guidance notes Electrical Addendum if power is required. Attachments that remain in place for more than 8 weeks must also meet the structural testing requirements set out in the Structures Addendum.',
    },
    required_when => {
    },
);

has_field electrical_information => (
    type => 'Text',
    widget => 'Textarea',
    label => 'Any relevant information relating to electrical power usage or structural testing?',
);

1;
