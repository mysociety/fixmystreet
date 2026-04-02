package FixMyStreet::App::Form::Licence::BuildingHighway;

use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Licence::Base';
use utf8;

# Type identifier used in URL: /licence/building-over-highway
sub type { 'building-over-highway' }

# Human-readable name for display
sub name { 'Building over the Highway' }

sub tandc_link { 'https://content.tfl.gov.uk/building-over-the-highway-guidance-notes-and-terms-conditions.pdf' }

sub next_after_contractor { 'activity' }

sub num_steps { 14 }

# ==========================================================================
# Introduction / Before you get started
# ==========================================================================
has_page intro => (
    fields => ['start'],
    title => 'Building Over Highway licence application',
    intro => 'building_over_highway/intro.html',
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
    step_number => 1,
    fields => ['building_name_number', 'street_name', 'borough', 'postcode', 'continue'],
    title => 'Location of building over the highway',
    intro => 'location.html',
    next => 'dates',
    post_process => sub {
        my $form = shift;
        $form->post_process_location;
    },
);

# ==========================================================================
# Building over highway activity
# ==========================================================================
has_page activity => (
    step_number => 5,
    fields => ['activity', 'continue'],
    title => 'Purpose of the building over the highway work',
    next => 'site_pedestrian_space',
);

has_field activity => (
    type => 'Text',
    widget => 'Textarea',
    label => 'What is the building work over the highway for?',
    required => 1,
    tags => {
        hint => 'For example, ‘temporary canopy’ or ‘temporary welfare unit’',
    },
);

# ==========================================================================
# Site Specific Information (building-over-highway-specific questions)
# Split into one question per page sometimes for better UX with long labels
# ==========================================================================
has_page site_pedestrian_space => (
    step_number => 6,
    fields => ['footway_incursion', 'aerial_clearance', 'continue'],
    title => 'Pedestrian space',
    next => 'site_carriageway_distance',
);

has_field footway_incursion => (
    type => 'Text',
    label => 'What is the proposed footway incursion?',
    required => 1,
    tags => {
        hint => 'For example, ‘1m from building line and 3m unobstructed footway’ or ‘no footway incursion’',
    },
);

has_field aerial_clearance => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Will any part of the structure (including any permanent supports) be less than 3.5m above the surface of the footway?',
    required => 1,
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

# ==========================================================================
has_page site_carriageway_distance => (
    step_number => 7,
    fields => ['carriageway_incursion', 'site_within_450mm', 'continue'],
    title => 'Carriageway impact',
    next => 'consent',
);

has_field carriageway_incursion => (
    type => 'Text',
    label => 'What is the proposed carriageway incursion?',
    required => 1,
    tags => {
        hint => 'For example, ‘no carriageway incursion’ or ‘temporary lane closure for installation’',
    },
);

has_field site_within_450mm => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Will any part of the building be within 450mm of the carriageway edge?',
    required => 1,
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

# ==========================================================================
has_page consent => (
    step_number => 8,
    fields => ['planning_consent', 'regulations_consent', 'continue'],
    title => 'Consents',
    next => 'site_infrastructure',
);

has_field planning_consent => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Has planning consent been granted for the structure?',
    required => 1,
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

has_field regulations_consent => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Does the structure have all appropriate consents under the Building Regulations?',
    required => 1,
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

# ==========================================================================
has_page site_infrastructure => (
    step_number => 9,
    fields => ['site_obstruct_infrastructure', 'continue'],
    title => 'Street infrastructure',
    next => 'have_you_considered',
);

has_field site_obstruct_infrastructure => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Will the building obstruct or obscure any street furniture, such as traffic signals, crossings, or signs?',
    tags => { hint => 'Other examples (not limited to) include bus stops, traffic signal controllers, lighting columns, parking bays, and ironwork.' },
    required => 1,
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
    step_number => 10,
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
    intro => 'building_over_highway/have_you_considered.html',
    next => 'terms',
);

has_page terms => (
    step_number => 11,
    fields => [
        'terms_accepted',
        'continue'
    ],
    title => 'Terms and conditions confirmation',
    next => 'uploads',
);

# ==========================================================================
# Upload required documents (scaffold-specific)
# ==========================================================================
my $upload_fields = [
    'upload_insurance',
    'insurance_validity',
    'upload_rams',
    'upload_site_drawing',
    'upload_building_regulations',
    'upload_planning_consent',
    'upload_additional',
    'continue'
];
has_page uploads => (
    step_number => 12,
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

has_field upload_site_drawing => (
    type => 'FileIdUpload',
    label => 'Site drawing',
    tags => {
        hint => 'Including measurements and available space maintained for pedestrians',
    },
    messages => {
        upload_file_not_found => 'Please upload a site drawing',
    },
);

has_field upload_building_regulations => (
    type => 'FileIdUpload',
    label => 'Building regulations',
    messages => {
        upload_file_not_found => 'Please upload your proof of meeting building regulations',
    },
);

has_field upload_planning_consent => (
    type => 'FileIdUpload',
    label => 'Planning consent',
    messages => {
        upload_file_not_found => 'Please upload proof of planning consent',
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
