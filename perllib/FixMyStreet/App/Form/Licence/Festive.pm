package FixMyStreet::App::Form::Licence::Festive;

use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Licence::Base';
use utf8;

with 'FixMyStreet::App::Form::Licence::Fields::Electrical';

# Type identifier used in URL: /licence/festive
sub type { 'festive' }

# Human-readable name for display
sub name { 'Festive Decorations' }

sub tandc_link { 'https://content.tfl.gov.uk/festive-decorations-guidance-notes-and-terms-conditions.pdf' }

sub next_after_contractor { 'activity' }

# ==========================================================================
# Introduction / Before you get started
# ==========================================================================
has_page intro => (
    fields => ['start'],
    title => 'Festive Decorations licence application',
    intro => 'festive/intro.html',
    next => 'location',
);

has_field start => (
    type => 'Submit',
    value => 'Start application',
    element_attr => { class => 'govuk-button' },
);

# ==========================================================================
# Location (fields from Fields::Location role)
# ==========================================================================
has_page location => (
    fields => ['building_name_number', 'street_name', 'borough', 'postcode', 'continue'],
    title => 'Location of the festive decorations',
    intro => 'location.html',
    next => 'dates',
    post_process => sub {
        my $form = shift;
        $form->post_process_location;
    },
);

# ==========================================================================
# Activity
# ==========================================================================
has_page activity => (
    fields => ['activity', 'shown_decorations', 'continue'],
    title => 'Purpose of the festive decorations',
    next => 'installation',
);

has_field activity => (
    type => 'Text',
    widget => 'Textarea',
    label => 'What activity will the festive decorations be used for?',
    required => 1,
    tags => {
        hint => 'For example, ‘seasonal decorations attached to lamp columns’',
    },
);

has_field shown_decorations => (
    type => 'Text',
    label => 'What will be shown on the festive decorations? We also require an example of the proposed decorations as part of the application.',
    required => 1,
    tags => {
        hint => 'For example, ‘illuminated Christmas trees’',
    },
);

# ==========================================================================
# Installation method
# ==========================================================================
has_page installation => (
    fields => ['installation_method', 'code_of_practice', 'continue'],
    title => 'Installation',
    next => 'site_pedestrian_space',
);

has_field installation_method => (
    type => 'Text',
    label => 'How will the decorations be installed?',
    required => 1,
    tags => {
        hint => 'For example, ‘mobile elevating work platform’ or ‘cherry picker’. Note, a separate mobile apparatus application may also be required.',
    },
);

has_field code_of_practice => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Have you read and understood the CSS Seasonal Decorations Code of Practice?',
    required => 1,
    tags => { hint => FixMyStreet::Template::SafeString->new('Please read the <a href="https://theilp.org.uk/resources/" target="_blank">Code of Practice</a>. If no, then a site meeting between the applicant and TfL may be required.') },
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

# ==========================================================================
# Site Specific Information (licence-specific questions)
# Split into one question per page sometimes for better UX with long labels
# ==========================================================================
has_page site_pedestrian_space => (
    fields => ['site_adequate_space', 'footway_incursion', 'continue'],
    title => 'Pedestrian space',
    next => 'site_carriageway_distance',
);

has_field site_adequate_space => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Will pedestrian space be maintained in line with TfL requirements?',
    required => 1,
    tags => { hint => 'A minimum width of 2m on lightly used footways, 3m on medium‑use footways and 4m on busy footways, with no reduction on intensely used footways.' },
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

has_field footway_incursion => (
    type => 'Text',
    label => 'What is the proposed footway incursion?',
    required => 1,
    tags => {
        hint => 'For example, ‘1m from building line and 3m unobstructed footway’ or ‘no footway incursion’',
    },
);

# ==========================================================================
has_page site_carriageway_distance => (
    fields => ['carriageway_incursion', 'continue'],
    title => 'Carriageway impact',
    next => 'site_infrastructure',
);

has_field carriageway_incursion => (
    type => 'Text',
    label => 'What is the proposed carriageway incursion?',
    required => 1,
    tags => {
        hint => 'For example, ‘no carriageway incursion’ or ‘temporary mobile lane closure for installation’',
    },
);

# ==========================================================================
has_page site_infrastructure => (
    fields => ['site_obstruct_infrastructure', 'enough_space', 'power_supply', 'mpan_number', 'electrical_information', 'continue'],
    title => 'Street infrastructure',
    next => 'have_you_considered',
);

has_field site_obstruct_infrastructure => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Will any decorations obstruct or obscure any street furniture, such as traffic signals, crossings, or signs?',
    tags => { hint => 'Other examples (not limited to) include bus stops, traffic signal controllers, lighting columns, parking bays, and ironwork.' },
    required => 1,
    order => -1,
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

# ==========================================================================
# Have you considered? (TCSR/TTRO + T&Cs)
# Fields from Fields::TemporaryProhibition role
# ==========================================================================
has_page have_you_considered => (
    fields => [
        'parking_dispensation',
        'parking_bay_suspension',
        'bus_stop_suspension',
        'bus_lane_suspension',
        'road_closure_required',
        'tcsr_website_note',
        'continue'
    ],
    title => 'Additional considerations',
    intro => 'festive/have_you_considered.html',
    next => 'terms',
);

has_page terms => (
    fields => [
        'terms_accepted',
        'continue'
    ],
    title => 'Terms and conditions confirmation',
    next => 'uploads',
);

# ==========================================================================
# Upload required documents (licence-specific)
# ==========================================================================
my $upload_fields = [
    'upload_insurance',
    'insurance_validity',
    'upload_rams',
    'upload_map',
    'upload_structural_testing',
    'upload_additional',
    'continue'
];
has_page uploads => (
    fields => $upload_fields,
    title => 'Upload required documents',
    intro => 'uploads.html',
    next => 'payment',
    update_field_list => sub {
        my ($form) = @_;
        my $fields = {};
        foreach (@$upload_fields) {
            next unless $_ =~ /^upload_/;
            $form->handle_upload($_, $fields);
        }
        return $fields;
    },
    post_process => sub {
        my ($form) = @_;
        foreach (@$upload_fields) {
            next unless $_ =~ /^upload_/;
            $form->process_upload($_);
        }
    },
);

has_field upload_map => (
    type => 'FileIdUpload',
    label => 'Map showing the location of each of the decorations',
    messages => {
        upload_file_not_found => 'Please upload a map',
    },
);

has_field upload_structural_testing => (
    type => 'FileIdUpload',
    label => 'Structural Testing',
    tags => {
        hint => 'Design Calculations in accordance with CD354 Design of minor structures; Asset load Testing onsite aligned with design calculations and BS EN40; Design and Check Certificate in accordance with Appendix J of CG 300',
    },
    messages => {
        upload_file_not_found => 'Please upload structural testing',
    },
);

has_field upload_additional => (
    type => 'FileIdUpload',
    label => 'Additional supporting documentation',
    messages => {
        upload_file_not_found => 'Please upload any additional supporting documentation',
    },
);

__PACKAGE__->meta->make_immutable;

1;
