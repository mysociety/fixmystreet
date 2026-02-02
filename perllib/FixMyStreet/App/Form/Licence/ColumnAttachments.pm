package FixMyStreet::App::Form::Licence::ColumnAttachments;

use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Wizard';
use utf8;

# Shared field roles
with 'FixMyStreet::App::Form::Licence::Fields::Location';
with 'FixMyStreet::App::Form::Licence::Fields::Dates';
with 'FixMyStreet::App::Form::Licence::Fields::Applicant';
with 'FixMyStreet::App::Form::Licence::Fields::Contractor';
with 'FixMyStreet::App::Form::Licence::Fields::TemporaryProhibition';

# Type identifier used in URL: /licence/column-attachements
sub type { 'column-attachments' }

# Human-readable name for display
sub name { 'Column Attachments' }

has upload_subdir => ( is => 'ro', default => 'tfl_licence_column_attachments_files' );

has default_page_type => ( is => 'ro', isa => 'Str', default => 'Wizard' );

has finished_action => ( is => 'ro', default => 'process_licence' );

has '+is_html5' => ( default => 1 );

# ==========================================================================
# Introduction / Before you get started
# ==========================================================================
has_page intro => (
    fields => ['start'],
    title => 'Column Attachements Licence Application',
    intro => 'column-attachments/intro.html',
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
    title => 'Location of the Column Attachments',
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
    intro => 'column-attachments/applicant.html',
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
    title => 'Contractor details (Column Attachments Contractor)',
    next => 'activity',
);


# ==========================================================================
# Column Attachments activity
# ==========================================================================
has_page activity => (
    fields => ['column_activity', 'continue'],
    title => 'Purpose of the column attachments',
    next => 'installation',
);

has_field column_activity => (
    type => 'Text',
    widget => 'Textarea',
    label => 'What activity will the licence be used for?',
    required => 1,
    tags => {
        hint => 'For example, “sensor attached to lamp columns for temporary traffic monitoring”',
    },
);

has_page installation => (
    fields => ['installation_method', 'continue'],
    title => 'Installation',
    next => 'site_pedestrian_space',
);

has_field installation_method => (
    type => 'Text',
    widget => 'Textarea',
    label => 'How will the column attachment be installed?',
    required => 1,
    tags => {
        hint => 'For example, “mobile elevating work platform” or “cherry picker”. Note a separate mobile apparatus application may also required',
    },
);

# ==========================================================================
# Site Specific Information (column-specific questions)
# Split into one question per page sometimes for better UX with long labels
# ==========================================================================
has_page site_pedestrian_space => (
    fields => ['column_footway_incursion', 'site_adequate_space', 'site_adequate_footway_headroom', 'continue'],
    title => 'Pedestrian space',
    next => 'site_carriageway_distance',
);

has_field column_footway_incursion => (
    type => 'Text',
    widget => 'Textarea',
    label => 'What is the proposed footway incursion?',
    required => 1,
    tags => {
        hint => 'For example, “1m from building line and 3m unobstructed footway” or “no footway incursion”',
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

has_field site_adequate_footway_headroom => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Will the headroom over any footway be less than 2m?',
    required => 1,
    tags => { hint => 'If yes, then a site meeting between the applicant and TfL may be required.' },
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

# ==========================================================================
has_page site_carriageway_distance => (
    fields => ['column_carriageway_incursion', 'site_adequate_carriageway_headroom', 'continue'],
    title => 'Carriageway impact',
    next => 'street_furniture',
);

has_field column_carriageway_incursion => (
    type => 'Text',
    widget => 'Textarea',
    label => 'What is the proposed carriageway incursion?',
    required => 1,
    tags => {
        hint => 'For example, “No carriageway incursion” or “temporary mobile lane closure for installation”',
    },
);

has_field site_adequate_carriageway_headroom => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Will the headroom over any carriageway be less than 6m?',
    tags => { hint => 'If yes, then a site meeting between the applicant and TfL may be required.' },
    required => 1,
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

has_page 'street_furniture' => (
    fields => ['pedestrian_crossing_proximity', 'street_furniture_proximity', 'continue'],
    title => 'Street furniture proximity',
    next => 'have_you_considered',
);

has_field pedestrian_crossing_proximity => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Will any attachments be within 20m of a junction or a pedestrian crossing point?',
    tags => { hint => 'If yes, then a site meeting between the applicant and TfL may be required.' },
    required => 1,
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

has_field street_furniture_proximity => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Will any attachments obstruct or obscure any of the following: traffic signal, traffic signal controller, bus stop, pedestrian crossing, junction sight line, road lighting column, traffic sign, parking bay, or any ‘ironwork’ in the highway or other street furniture?',
    tags => { hint => 'If yes, then a site meeting between the applicant and TfL may be required.' },
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
    intro => 'column-attachments/have_you_considered.html',
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
# Upload required documents (column-specific)
# ==========================================================================
has_page uploads => (
    fields => [
        'upload_insurance',
        'upload_rams',
        'upload_column_site_drawing',
        'upload_column_technical_report',
        'upload_design_calculation',
        'upload_load_testing',
        'upload_check_certificate',
        'continue'
    ],
    title => 'Upload required documents',
    intro => 'column-attachments/uploads.html',
    next => 'payment',
    update_field_list => sub {
        my ($form) = @_;
        my $fields = {};
        $form->handle_upload('upload_insurance', $fields);
        $form->handle_upload('upload_rams', $fields);
        $form->handle_upload('upload_column_site_drawing', $fields);
        $form->handle_upload('upload_column_technical_report', $fields);
        $form->handle_upload('upload_design_calculation', $fields);
        $form->handle_upload('upload_load_testing', $fields);
        $form->handle_upload('upload_check_certificate', $fields);
        return $fields;
    },
    post_process => sub {
        my ($form) = @_;
        $form->process_upload('upload_insurance');
        $form->process_upload('upload_rams');
        $form->process_upload('upload_column_site_drawing');
        $form->process_upload('upload_column_technical_report');
        $form->process_upload('upload_design_calculation');
        $form->process_upload('upload_load_testing');
        $form->process_upload('upload_check_certificate');
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

has_field upload_column_site_drawing => (
    type => 'FileIdUpload',
    label => 'Site drawing',
    messages => {
        upload_file_not_found => 'Please upload a site drawing',
    },
);

has_field upload_column_technical_report => (
    type => 'FileIdUpload',
    label => 'Technical Note / report on the design',
    messages => {
        upload_file_not_found => 'Please upload a technical report',
    },
);

has_field upload_design_calculation => (
    type => 'FileIdUpload',
    label => 'Design Calculations - In accordance with CD354 Design of minor structures',
    messages => {
        upload_file_not_found => 'Please upload a design calculation',
    },
);

has_field upload_load_testing => (
    type => 'FileIdUpload',
    label => 'Asset load Testing onsite aligned with design calculations and BS EN40',
    messages => {
        upload_file_not_found => 'Please upload a load testing document',
    },
);

has_field upload_check_certificate => (
    type => 'FileIdUpload',
    label => 'Design and Check Certificate - In accordance with Appendix J of CG 300',
    messages => {
        upload_file_not_found => 'Please upload a design and check certificate',
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
