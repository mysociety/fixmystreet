package FixMyStreet::App::Form::Licence::Excavation;

use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Licence::Base';
use utf8;

# Type identifier used in URL: /licence/excavation
sub type { 'excavation' }

# Human-readable name for display
sub name { 'Excavation' }

sub tandc_link { 'https://content.tfl.gov.uk/excavation-in-the-highway-guidance-notes-and-terms-conditions.pdf' }

sub next_after_contractor { 'activity' }

sub num_steps { 13 }

# ==========================================================================
# Introduction / Before you get started
# ==========================================================================
has_page intro => (
    fields => ['start'],
    title => 'Excavation in the Highway licence application',
    intro => 'excavation/intro.html',
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
    title => 'Location of the excavation',
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
    step_number => 5,
    fields => ['activity', 'excavation_position', 'continue'],
    title => 'Purpose of the excavation',
    next => 'site_pedestrian_space',
);

has_field activity => (
    type => 'Text',
    widget => 'Textarea',
    label => 'What is the reason for the excavation?',
    required => 1,
    tags => {
        hint => 'For example, ‘trial pit to determine location of underground services’',
    },
);

has_field excavation_position => (
    type => 'Text',
    label => "What is the position and dimensions of the excavation?",
    required => 1,
    tags => {
        hint => 'For example, ‘corner between two roads’ and ‘1m by 1m’',
    },
);

# ==========================================================================
# Site Specific Information (licence-specific questions)
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
    label => 'What is the proposed footway incursion?',
    required => 1,
    tags => {
        hint => 'For example, ‘1m from building line and 3m unobstructed footway’ or ‘no footway incursion’',
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
    label => 'What is the proposed carriageway incursion?',
    required => 1,
    tags => {
        hint => 'For example, ‘no carriageway incursion’ or ‘temporary lane closure for installation’',
    },
);

has_field site_within_450mm => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Will the excavation be within 450mm of the carriageway edge?',
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
    label => 'Will the excavation impact any of the following: traffic signal, traffic signal controller, bus stop, pedestrian crossing, junction sight line, road lighting column, traffic sign, parking bay, or any ‘ironwork’ in the highway or other street furniture?',
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
    intro => 'excavation/have_you_considered.html',
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
# Upload required documents (licence-specific)
# ==========================================================================
my $upload_fields = [
    'upload_insurance',
    'insurance_validity',
    'upload_rams',
    'upload_site_drawing',
    'upload_traffic_management',
    'upload_additional',
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
    tags => {
        hint => 'Including measurements and available space maintained for pedestrians',
    },
    messages => {
        upload_file_not_found => 'Please upload a site drawing',
    },
);

has_field upload_traffic_management => (
    type => 'FileIdUpload',
    label => 'Traffic Management plan',
    messages => {
        upload_file_not_found => 'Please upload a traffic management plan',
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
