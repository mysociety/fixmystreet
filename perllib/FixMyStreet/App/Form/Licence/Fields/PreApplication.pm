package FixMyStreet::App::Form::Licence::Fields::PreApplication;

use utf8;
use HTML::FormHandler::Moose::Role;

=head1 NAME

FixMyStreet::App::Form::Licence::Fields::PreApplication - Pre-application consultation fields for licence forms

=head1 DESCRIPTION

Provides questions & links regarding pre-application consultations for certain
TfL licence forms (Crane, MobileApparatus, PitLane). Fields are:
buses_consulted
underground_consulted
police_consulted
preapp_comments

=cut

has_field buses_consulted => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Have TfL Buses been consulted on the proposed works?',
    required => 1,
    tags => {
        hint => FixMyStreet::Template::SafeString->new(
            '<a href="https://tfl.gov.uk/modes/buses/" target="_blank">Buses - Transport for London</a>'
        ),
    },
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

has_field underground_consulted => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Have TfL London Underground – Infrastructure Protection been consulted on the proposed works?',
    required => 1,
    tags => {
        hint => FixMyStreet::Template::SafeString->new(
            '<a href="https://tfl.gov.uk/info-for/urban-planning-and-construction/our-land-and-infrastructure/working-on-or-near-TfL-transport-assets-and-property" target="_blank">Working on or near TfL transport assets and property - Transport for London</a>'
        ),
    },
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

has_field police_consulted => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Have the Metropolitan Police - Safer Transport Teams been consulted on the proposed works?',
    required => 1,
    tags => {
        hint => FixMyStreet::Template::SafeString->new(
            '<a href="https://www.met.police.uk/contact/af/contact-us-beta/contact-us/" target="_blank">Contact us | Metropolitan Police</a>'
        ),
    },
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

has_field preapp_comments => (
    type => 'Text',
    widget => 'Textarea',
    label => 'If you selected ‘No’ for any of the above, you must explain why. You may also provide any additional relevant comments relating to the pre-application consultation in the section below.',
    required => 1,
);

1;
