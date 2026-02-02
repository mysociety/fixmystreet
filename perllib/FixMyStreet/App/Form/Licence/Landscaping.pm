package FixMyStreet::App::Form::Licence::Landscaping;

use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Wizard';
use utf8;

# Shared field roles
with 'FixMyStreet::App::Form::Licence::Fields::Location';
with 'FixMyStreet::App::Form::Licence::Fields::Dates';
with 'FixMyStreet::App::Form::Licence::Fields::Applicant';
with 'FixMyStreet::App::Form::Licence::Fields::Contractor';
with 'FixMyStreet::App::Form::Licence::Fields::TemporaryProhibition';

# Type identifier used in URL: /licence/landscaping
sub type { 'landscaping' }

# Human-readable name for display
sub name { 'Landscaping/Planting' }

has upload_subdir => ( is => 'ro', default => 'tfl_licence_landscaping_files' );

has default_page_type => ( is => 'ro', isa => 'Str', default => 'Wizard' );

has finished_action => ( is => 'ro', default => 'process_licence' );

has '+is_html5' => ( default => 1 );

# ==========================================================================
# Introduction / Before you get started
# ==========================================================================
has_page intro => (
    fields => ['start'],
    title => 'Landscaping/Planting Licence Application',
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
    intro => 'landscaping/applicant.html',
    next => 'contractor',
);

# ==========================================================================
# About You (Principal Contractor)
# Fields from Fields::Contractor role
# ==========================================================================
has_page contractor => (
    fields => [
        'contractor_same_as_applicant',
        'contractor_organisation',
        'contractor_contact_name',
        'contractor_address',
        'contractor_email',
        'contractor_phone',
        'contractor_phone_24h',
        'continue'
    ],
    title => 'Contractor details (Landscaping/Planting Contractor)',
    next => 'activity',
);


# ==========================================================================
# Landscaping activity
# ==========================================================================
has_page activity => (
    fields => ['landscaping_activity', 'landscaping_description', 'continue'],
    title => 'Purpose of the landscaping or planting',
    next => 'site_pedestrian_space',
);

has_field landscaping_activity => (
    type => 'Text',
    widget => 'Textarea',
    label => 'What activity will the licence be used for?',
    required => 1,
    tags => {
        hint => 'For example, "maintenance of roundabout or central reserve"',
    },
);

has_field landscaping_description => (
    type => 'Text',
    widget => 'Textarea',
    label => 'General description of the proposed works',
    required => 1,
    tags => {
        hint => 'For example, “planting of ten semi mature silver birch trees” or “sponsored maintenance of roundabout landscape maintenance”',
    },
);

# ==========================================================================
# Site Specific Information (landscaping-specific questions)
# Split into one question per page sometimes for better UX with long labels
# ==========================================================================
has_page site_pedestrian_space => (
    fields => ['landscaping_footway_incursion', 'site_adequate_space', 'continue'],
    title => 'Pedestrian space',
    next => 'site_carriageway_distance',
);

has_field landscaping_footway_incursion => (
    type => 'Text',
    widget => 'Textarea',
    label => 'What is the proposed footway incursion?',
    required => 1,
    tags => {
        hint => 'For example, “no footway incursion, planting taking place on the roundabout”',
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
    fields => ['landscaping_carriageway_incursion', 'site_within_450mm', 'continue'],
    title => 'Carriageway impact',
    next => 'site_infrastructure',
);

has_field landscaping_carriageway_incursion => (
    type => 'Text',
    widget => 'Textarea',
    label => 'What is the proposed carriageway incursion?',
    required => 1,
    tags => {
        hint => 'For example, “No carriageway incursion” or “temporary lane closure for planting”',
    },
);

has_field site_within_450mm => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Will any planting grow to within 450mm of the carriageway edge?',
    tags => { hint => 'If yes, then a site meeting between the applicant and TfL may be required.' },
    required => 1,
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

# ==========================================================================
has_page site_infrastructure => (
    fields => ['site_obstruct_infrastructure', 'continue'],
    title => 'Street infrastructure',
    next => 'have_you_considered',
);

has_field site_obstruct_infrastructure => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Will any planting grow to obstruct or obscure any of the following: traffic signals, signal controllers, bus stops, pedestrian crossings, junction sight lines, road lighting columns, traffic signs, parking bays, ironwork in the highway, or other street furniture?',
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
    intro => 'landscaping/have_you_considered.html',
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
# Upload required documents (landscaping-specific)
# ==========================================================================
has_page uploads => (
    fields => [
        'upload_insurance',
        'upload_rams',
        'upload_landscaping_site_drawing',
        'upload_landscaping_specification',
        'continue'
    ],
    title => 'Upload required documents',
    intro => 'landscaping/uploads.html',
    next => 'payment',
    update_field_list => sub {
        my ($form) = @_;
        my $fields = {};
        $form->handle_upload('upload_insurance', $fields);
        $form->handle_upload('upload_rams', $fields);
        $form->handle_upload('upload_landscaping_site_drawing', $fields);
        $form->handle_upload('upload_landscaping_specification', $fields);
        return $fields;
    },
    post_process => sub {
        my ($form) = @_;
        $form->process_upload('upload_insurance');
        $form->process_upload('upload_rams');
        $form->process_upload('upload_landscaping_site_drawing');
        $form->process_upload('upload_landscaping_specification');
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

has_field upload_rams => (
    type => 'FileIdUpload',
    label => 'Risk Assessment Method Statement (RAMS)',
    messages => {
        upload_file_not_found => 'Please upload your Risk Assessment Method Statement',
    },
);

has_field upload_landscaping_site_drawing => (
    type => 'FileIdUpload',
    label => 'Site drawing',
    messages => {
        upload_file_not_found => 'Please upload a site drawing',
    },
);


has_field upload_landscaping_specification => (
    type => 'FileIdUpload',
    label => 'Landscaping specification / Planting schedule',
    messages => {
        upload_file_not_found => 'Please upload a landscaping specification or planting schedule',
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
        my $c = $form->{c};
        # FIXME
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
