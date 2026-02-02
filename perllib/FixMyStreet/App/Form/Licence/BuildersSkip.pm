package FixMyStreet::App::Form::Licence::BuildersSkip;

use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Wizard';
use utf8;

# Shared field roles
with 'FixMyStreet::App::Form::Licence::Fields::Location';
with 'FixMyStreet::App::Form::Licence::Fields::Dates';
with 'FixMyStreet::App::Form::Licence::Fields::Applicant';
with 'FixMyStreet::App::Form::Licence::Fields::TemporaryProhibition';

# Type identifier used in URL: /licence/builders-skip
sub type { 'builders-skip' }

# Human-readable name for display
sub name { 'Builder’s skip' }

has upload_subdir => ( is => 'ro', default => 'tfl_licence_builders_skip_files' );

has default_page_type => ( is => 'ro', isa => 'Str', default => 'Wizard' );

has finished_action => ( is => 'ro', default => 'process_licence' );

has '+is_html5' => ( default => 1 );

# ==========================================================================
# Introduction / Before you get started
# ==========================================================================
has_page intro => (
    fields => ['start'],
    title => 'Builder’s Skip Licence Application',
    intro => 'builders-skip/intro.html',
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
    title => 'Location of the skip',
    intro => 'location.html',
    next => 'dates',
    post_process => sub {
        my $form = shift;
        $form->post_process_location;
    },
);

# ==========================================================================
# Dates (fields from Fields::Dates role)
# ==========================================================================
has_page dates => (
    fields => ['proposed_start_date', 'proposed_duration', 'year_warning', 'continue'],
    title => 'Proposed working dates',
    intro => 'dates.html',
    next => 'applicant',
);

# ==========================================================================
# About You (Applicant)
# Fields: organisation, address, phone_24h from Fields::Applicant role
# Fields: name, email, phone from AboutYou role
# ==========================================================================
has_page applicant => (
    fields => [
        'organisation',
        'name',
        'job_title',
        'address',
        'email',
        'phone',
        'phone_24h',
        'continue'
    ],
    title => 'Applicant details',
    next => 'activity',
);

# ==========================================================================
# Skip activity
# ==========================================================================
has_page activity => (
    fields => ['skip_activity', 'continue'],
    title => 'Purpose of the skip',
    next => 'vehicle',
);

has_field skip_activity => (
    type => 'Text',
    widget => 'Textarea',
    label => 'What activity will the skip be used for?',
    required => 1,
    tags => {
        hint => 'For example, "new build", "demolition" or "building repair"',
    },
);

# ==========================================================================
# Directly to a vehicle
# ==========================================================================
has_page vehicle => (
    fields => ['vehicle_directly', 'continue'],
    title => 'Direct loading',
    next => 'site_pedestrian_space',
);

has_field vehicle_directly => (
    type => 'Text',
    widget => 'Textarea',
    label => "Explain why materials cannot be loaded directly into a vehicle.",
    required => 1,
    tags => {
        hint => 'Note: there is a presumption against granting consent to builders skips on London’s Red Routes, the preferred means of disposal of materials being to load directly into a waiting vehicle.',
    },
);


# ==========================================================================
# Site Specific Information (skip-specific questions)
# Split into one question per page sometimes for better UX with long labels
# ==========================================================================
has_page site_pedestrian_space => (
    fields => ['footway_incursion', 'site_adequate_space', 'continue'],
    title => 'Pedestrian space',
    next => 'site_carriageway_distance',
);

has_field footway_incursion => (
    type => 'Text',
    label => 'What is the proposed footway incursion?',
    required => 1,
    tags => {
        hint => 'For example, "1m from building line and 3m unobstructed footway" or "no footway incursion"',
    },
);

has_field site_adequate_space => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Will pedestrian space be maintained in line with TfL requirements - 2m for lightly used footways, 3m for medium-use footways and 4m for busy footways, with no reduction of width for intensely used footways?',
    required => 1,
    tags => { hint => 'If no, then a site meeting between the applicant and TfL may be required.' },
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

# ==========================================================================
has_page site_carriageway_distance => (
    fields => ['carriageway_incursion', 'located_on_carriageway', 'continue'],
    title => 'Carriageway impact',
    next => 'site_obstructions',
);

has_field carriageway_incursion => (
    type => 'Text',
    label => 'What is the proposed carriageway incursion?',
    required => 1,
    tags => {
        hint => 'For example, "no carriageway incursion" or "temporary lane closure for installation"',
    },
);

has_field located_on_carriageway => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Will the skip be located in the main carriageway?',
    tags => { hint => 'If yes, then a site meeting between the applicant and TfL may be required.' },
    required => 1,
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

# ==========================================================================
has_page site_obstructions => (
    fields => ['site_obstruct_location', 'site_obstruct_infrastructure', 'continue'],
    title => 'Site obstructions',
    next => 'have_you_considered',
);

has_field site_obstruct_location => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Will the skip be located in a ‘service road’, lay-by or footway crossing?',
    required => 1,
    tags => {
        hint => "If yes, a site meeting between the applicant and TfL may be required.",
    },
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

has_field site_obstruct_infrastructure => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Will the skip obstruct or obscure any of the following: traffic signal, traffic signal controller, bus stop, pedestrian crossing, junction sight line, road lighting column, traffic sign, parking bay, or any ‘ironwork’ in the highway or other street furniture?',
    tags => { hint => 'If yes, a site meeting between the applicant and TfL may be required.' },
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
    fields => [
        'parking_dispensation',
        'parking_bay_suspension',
        'bus_stop_suspension',
        'bus_lane_suspension',
        'road_closure_required',
        'continue'
    ],
    title => 'Additional considerations',
    intro => 'builders-skip/have_you_considered.html',
    next => 'terms',
);

has_page terms => (
    fields => [
        'terms_accepted',
        'continue'
    ],
    title => 'Terms and conditions',
    next => 'uploads',
);

# ==========================================================================
# Upload required documents (skip-specific)
# ==========================================================================
has_page uploads => (
    fields => [
        'upload_insurance',
        'upload_site_drawing',
        'upload_additional',
        'continue'
    ],
    title => 'Upload required documents',
    intro => 'builders-skip/uploads.html',
    next => 'payment',
    update_field_list => sub {
        my ($form) = @_;
        my $fields = {};
        $form->handle_upload('upload_insurance', $fields);
        $form->handle_upload('upload_site_drawing', $fields);
        $form->handle_upload('upload_additional', $fields);
        return $fields;
    },
    post_process => sub {
        my ($form) = @_;
        $form->process_upload('upload_insurance');
        $form->process_upload('upload_site_drawing');
        $form->process_upload('upload_additional');
    },
);

has_field upload_insurance => (
    type => 'FileIdUpload',
    label => 'Public Liability Insurance certificate',
    tags => {
        hint => 'Minimum cover of £10 million',
    },
    messages => {
        upload_file_not_found => 'Please upload your Public Liability Insurance certificate',
    },
);

has_field upload_site_drawing => (
    type => 'FileIdUpload',
    label => 'Site drawing',
    messages => {
        upload_file_not_found => 'Please upload a site drawing',
    },
);

has_field upload_additional => (
    type => 'FileIdUpload',
    label => 'Additional supporting documentation',
    messages => {
        upload_file_not_found => 'Please upload any additional supporting documentation',
    },
);

# ==========================================================================
# Payment
# ==========================================================================
has_page payment => (
    fields => [
        'payment_transaction_id',
        'continue'
    ],
    title => 'Payment',
    intro => 'payment.html',
    next => 'summary',

    update_field_list => sub {
        my $form = shift;
        my $data = $form->saved_data;
        my $c = $form->{c};
        $c->stash->{payment_link} = 'LINK';
        return {};
    },
);

has_field payment_transaction_id => (
    type => 'Text',
    label => 'Transaction ID',
);

# ==========================================================================
# Summary
# ==========================================================================
has_page summary => (
    fields => ['submit'],
    title => 'Application Summary',
    template => 'licence/summary.html',
    finished => sub {
        my $form = shift;
        my $c = $form->c;
        my $success = $c->forward('process_licence', [ $form ]);
        if (!$success) {
            $form->add_form_error('Something went wrong, please try again');
        }
        return $success;
    },
    next => 'done',
);

has_field submit => (
    type => 'Submit',
    value => 'Submit application',
    element_attr => { class => 'govuk-button' },
);

# ==========================================================================
# Confirmation
# ==========================================================================
has_page done => (
    title => 'Application complete',
    template => 'licence/confirmation.html',
);

# ==========================================================================
# Shared fields
# ==========================================================================
has_field continue => (
    type => 'Submit',
    value => 'Continue',
    element_attr => { class => 'govuk-button' },
);

__PACKAGE__->meta->make_immutable;

1;
