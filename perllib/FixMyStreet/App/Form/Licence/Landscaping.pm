package FixMyStreet::App::Form::Licence::Landscaping;

use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Licence::Base';
use utf8;

# Type identifier used in URL: /licence/landscaping
sub type { 'landscaping' }

# Human-readable name for display
sub name { 'Landscaping/Planting' }

sub tandc_link { 'https://content.tfl.gov.uk/landscaping-planting-guidance-notes-and-terms-conditions.pdf' }

sub next_after_contractor { 'activity' }

sub num_steps { 13 }

# ==========================================================================
# Introduction / Before you get started
# ==========================================================================
has_page intro => (
    fields => ['start'],
    title => 'Landscaping/Planting licence application',
    intro => 'landscaping/intro.html',
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
    title => 'Location of the Landscaping/Planting',
    intro => 'location.html',
    next => 'dates',
    post_process => sub {
        my $form = shift;
        $form->post_process_location;
    },
);

# ==========================================================================
# Landscaping activity
# ==========================================================================
has_page activity => (
    step_number => 5,
    fields => ['activity', 'description', 'continue'],
    title => 'Purpose of the landscaping or planting',
    next => 'site_pedestrian_space',
);

has_field activity => (
    type => 'Text',
    widget => 'Textarea',
    label => 'What activity will the licence be used for?',
    required => 1,
    tags => {
        hint => 'For example, ‘maintenance of roundabout or central reserve’',
    },
);

has_field description => (
    type => 'Text',
    widget => 'Textarea',
    label => 'General description of the proposed works',
    required => 1,
    tags => {
        hint => 'For example, ‘planting of ten semi mature silver birch trees’ or ‘sponsored maintenance of roundabout landscape maintenance’',
    },
);

# ==========================================================================
# Site Specific Information (landscaping-specific questions)
# Split into one question per page sometimes for better UX with long labels
# ==========================================================================
has_page site_pedestrian_space => (
    step_number => 6,
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
    widget => 'Textarea',
    label => 'What is the proposed footway incursion?',
    required => 1,
    tags => {
        hint => 'For example, ‘no footway incursion, planting taking place on the roundabout’',
    },
);

# ==========================================================================
has_page site_carriageway_distance => (
    step_number => 7,
    fields => ['carriageway_incursion', 'site_within_450mm', 'continue'],
    title => 'Carriageway impact',
    next => 'site_infrastructure',
);

has_field carriageway_incursion => (
    type => 'Text',
    widget => 'Textarea',
    label => 'What is the proposed carriageway incursion?',
    required => 1,
    tags => {
        hint => 'For example, ‘No carriageway incursion’ or ‘temporary lane closure for planting’',
    },
);

has_field site_within_450mm => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Will any planting grow to within 450mm of the carriageway edge?',
    required => 1,
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

# ==========================================================================
has_page site_infrastructure => (
    step_number => 8,
    fields => ['site_obstruct_infrastructure', 'continue'],
    title => 'Street infrastructure',
    next => 'have_you_considered',
);

has_field site_obstruct_infrastructure => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Will any planting grow to obstruct or obscure any street furniture, such as traffic signals, crossings, or signs?',
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
    step_number => 9,
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
    intro => 'landscaping/have_you_considered.html',
    next => 'terms',
);

has_page terms => (
    step_number => 10,
    fields => [
        'terms_accepted',
        'continue'
    ],
    title => 'Terms and conditions confirmation',
    next => 'uploads',
);

# ==========================================================================
# Upload required documents (landscaping-specific)
# ==========================================================================
my $upload_fields = [
    'upload_insurance',
    'insurance_validity',
    'upload_rams',
    'upload_site_drawing',
    'upload_specification',
    'continue'
];
has_page uploads => (
    step_number => 11,
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
    messages => {
        upload_file_not_found => 'Please upload a site drawing',
    },
);


has_field upload_specification => (
    type => 'FileIdUpload',
    label => 'Landscaping specification / Planting schedule',
    messages => {
        upload_file_not_found => 'Please upload a landscaping specification or planting schedule',
    },
);

__PACKAGE__->meta->make_immutable;

1;
