package FixMyStreet::App::Form::Licence::Scaffold;

use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Wizard';
use utf8;

# Shared field roles
with 'FixMyStreet::App::Form::Licence::Fields::Location';
with 'FixMyStreet::App::Form::Licence::Fields::Dates';
with 'FixMyStreet::App::Form::Licence::Fields::Applicant';
with 'FixMyStreet::App::Form::Licence::Fields::Contractor';
with 'FixMyStreet::App::Form::Licence::Fields::TemporaryProhibition';

# Type identifier used in URL: /licence/scaffold
sub type { 'scaffold' }

# Human-readable name for display
sub name { 'Scaffold' }

has upload_subdir => ( is => 'ro', default => 'tfl_licence_scaffold_files' );

has default_page_type => ( is => 'ro', isa => 'Str', default => 'Wizard' );

has finished_action => ( is => 'ro', default => 'process_licence' );

has '+is_html5' => ( default => 1 );

# ==========================================================================
# Introduction / Before you get started
# ==========================================================================
has_page intro => (
    fields => ['start'],
    title => 'Scaffold Licence Application',
    intro => 'scaffold/intro.html',
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
    title => 'Location of the scaffold',
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
    intro => 'applicant.html',
    next => 'contractor',
);

# ==========================================================================
# About You (Principal Contractor)
# Fields from Fields::Contractor role, plus scaffold-specific NASC question
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
        'contractor_nasc_member',
        'contractor_meeting',
        'continue'
    ],
    title => 'Contractor details (Scaffold Contractor)',
    next => 'dimensions',
);

has_field contractor_nasc_member => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Is the scaffold contractor a member of a regulated scaffolding association, such as NASC?',
    required => 1,
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

has_field contractor_meeting => (
    type => 'Checkbox',
    label => '',
    option_label => 'I confirm that a site meeting has taken place between the Applicant and the Scaffold Contractor',
);

# ==========================================================================
# Scaffold dimensions
# ==========================================================================
has_page dimensions => (
    fields => ['scaffold_height', 'scaffold_length', 'scaffold_width', 'continue'],
    title => 'Scaffold dimensions',
    next => 'scaffold_type',
);

has_field scaffold_height => (
    type => 'Text',
    label => 'Height (metres)',
    required => 1,
    tags => { number => 1 },
);

has_field scaffold_length => (
    type => 'Text',
    label => 'Length (metres)',
    required => 1,
    tags => { number => 1 },
);

has_field scaffold_width => (
    type => 'Text',
    label => 'Width / Depth (metres)',
    required => 1,
    tags => { number => 1 },
);

# ==========================================================================
# Scaffold type
# ==========================================================================
has_page scaffold_type => (
    fields => ['scaffold_type', 'scaffold_configured', 'continue'],
    title => 'Type of scaffold',
    intro => 'scaffold/type.html',
    next => 'activity',
    update_field_list => sub {
        my $form = shift;
        my $data = $form->saved_data;
        my $fields = {};

        my $length = $data->{scaffold_length};
        $fields->{scaffold_type}{default} = 'Scaffold (Large)' if $length >= 10;
        return $fields;
    },
);

has_field scaffold_type => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Scaffold type',
    required => 1,
    options_method => sub {
        my $self = shift;
        my $data = $self->form->saved_data;
        my $length = $data->{scaffold_length};
        my $disabled = $length >= 10 ? 1 : 0;
        return [
            { label => 'Scaffold', value => 'Scaffold', disabled => $disabled,
                hint => 'A standard scaffold less than 10 metres in length' },
            { label => 'Scaffold (Large)', value => 'Scaffold (Large)',
                hint => 'Any scaffold 10 metres or greater in length' },
            { label => 'Scaffold (Mobile Tower)', value => 'Scaffold (Mobile Tower)', disabled => $disabled,
                hint => 'For small mobile scaffold towers, only valid up to two weeks' },
        ];
    },
);

has_field scaffold_configured => (
    type => 'Text',
    label => 'How will the scaffold be configured?',
    required => 1,
    tags => {
        hint => 'For example, “independent”, “gantry” or “cantilever”',
    },
);

# ==========================================================================
# Scaffold activity
# ==========================================================================
has_page activity => (
    fields => ['scaffold_activity', 'continue'],
    title => 'Purpose of the scaffold',
    next => 'incursion',
);

has_field scaffold_activity => (
    type => 'Text',
    widget => 'Textarea',
    label => 'What activity will the scaffold be used for?',
    required => 1,
    tags => {
        hint => 'For example, "building repair" or "window replacement"',
    },
);

# ==========================================================================
# Incursion details
# ==========================================================================
has_page incursion => (
    fields => ['footway_incursion', 'carriageway_incursion', 'continue'],
    title => 'Footway and carriageway incursion',
    next => 'site_pedestrian_space',
);

has_field footway_incursion => (
    type => 'Text',
    label => 'What is the proposed footway incursion?',
    required => 1,
    tags => {
        hint => 'For example, "1m from building line and 3m unobstructed footway" or "no footway incursion"',
    },
);

has_field carriageway_incursion => (
    type => 'Text',
    label => 'What is the proposed carriageway incursion?',
    required => 1,
    tags => {
        hint => 'For example, "no carriageway incursion" or "temporary lane closure for installation"',
    },
);

# ==========================================================================
# Site Specific Information (scaffold-specific questions)
# Split into one question per page for better UX with long labels
# ==========================================================================
has_page site_pedestrian_space => (
    fields => ['site_adequate_space', 'continue'],
    title => 'Pedestrian space',
    intro => 'scaffold/site_specific.html',
    next => 'site_carriageway_distance',
);

has_field site_adequate_space => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Will adequate space be maintained for pedestrians as defined in section 4 of TfL’s Licensing Guidance, available from TfL’s Website i.e. 2m for lightly used footways, 3m for medium use footways, and 4 m for busy footways, with no reduction of width for intensely used footways?',
    required => 1,
    tags => { hint => 'If no, then a site meeting between the applicant and TfL may be required.' },
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
        { label => 'N/A', value => 'N/A' },
    ],
);

# ==========================================================================
has_page site_carriageway_distance => (
    fields => ['site_within_450mm', 'continue'],
    title => 'Distance from carriageway',
    next => 'site_infrastructure',
);

has_field site_within_450mm => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Will any part of the scaffold be within 450mm of the edge of carriageway?',
    tags => { hint => 'If yes, then a site meeting between the applicant and TfL may be required.' },
    required => 1,
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
        { label => 'N/A', value => 'N/A' },
    ],
);

# ==========================================================================
has_page site_infrastructure => (
    fields => ['site_obstruct_infrastructure', 'continue'],
    title => 'Street infrastructure',
    next => 'site_protection',
);

has_field site_obstruct_infrastructure => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Will the scaffolding obstruct or obscure any of the following: traffic signal, traffic signal controller, bus stop, pedestrian crossing, junction sight line, road lighting column, traffic sign, parking bay, or any ironwork in the highway or other street furniture?',
    tags => { hint => 'If yes, then a site meeting between the applicant and TfL may be required.' },
    required => 1,
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
        { label => 'N/A', value => 'N/A' },
    ],
);

# ==========================================================================
has_page site_protection => (
    fields => ['site_protection_fan', 'continue'],
    title => 'Public protection',
    next => 'site_foundations',
);

has_field site_protection_fan => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Will a public protection fan and/or gantry be installed whilst the erection and dismantling of the scaffolding takes place?',
    tags => { hint => 'If yes, then a site meeting between the applicant and TfL may be required.' },
    required => 1,
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
        { label => 'N/A', value => 'N/A' },
    ],
);

# ==========================================================================
has_page site_foundations => (
    fields => ['site_foundations_surveyed', 'continue'],
    title => 'Foundations',
    next => 'site_hoarding',
);

has_field site_foundations_surveyed => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Have existing foundations been surveyed to ensure they are adequate to carry the loads imposed by the scaffolding structure?',
    required => 1,
    tags => {
        hint => 'If the answer is no, what additional measures are intended? (Give details in scaffold plan). If yes, then a site meeting between the applicant and TfL may be required.',
    },
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
        { label => 'N/A', value => 'N/A' },
    ],
);

# ==========================================================================
has_page site_hoarding => (
    fields => ['site_hoarding_attached', 'continue'],
    title => 'Hoarding',
    next => 'site_trees',
);

has_field site_hoarding_attached => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Will a hoarding be attached to the scaffolding?',
    required => 1,
    tags => {
        hint => "If the answer is yes, there will also be a requirement for a separate hoarding application, and a site meeting between the applicant and TfL may be required.",
    },
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
        { label => 'N/A', value => 'N/A' },
    ],
);

# ==========================================================================
has_page site_trees => (
    fields => ['site_trees_nearby', 'continue'],
    title => 'Nearby trees',
    next => 'have_you_considered',
);

has_field site_trees_nearby => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Are there any trees within falling distance of any part of the proposed scaffold?',
    required => 1,
    tags => {
        hint => "If answer is yes, then the application will be referred to the TfL Arboriculture & Landscape Manager for further consideration, and a site meeting between the applicant and TfL may be required.",
    },
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
        { label => 'N/A', value => 'N/A' },
    ],
);

# ==========================================================================
# Have you considered? (TCSR/TTRO + T&Cs)
# Fields from Fields::TemporaryProhibition role
# ==========================================================================
has_page have_you_considered => (
    fields => [
        'parking_bay_suspension',
        'road_closure_required',
        'terms_accepted',
        'continue'
    ],
    title => 'Additional considerations',
    intro => 'have_you_considered.html',
    next => 'uploads',
);

# ==========================================================================
# Upload required documents (scaffold-specific)
# ==========================================================================
has_page uploads => (
    fields => [
        'upload_insurance',
        'upload_rams',
        'upload_scaffold_drawing',
        'upload_additional',
        'continue'
    ],
    title => 'Upload required documents',
    intro => 'scaffold/uploads.html',
    next => 'payment',
    update_field_list => sub {
        my ($form) = @_;
        my $fields = {};
        $form->handle_upload('upload_insurance', $fields);
        $form->handle_upload('upload_rams', $fields);
        $form->handle_upload('upload_scaffold_drawing', $fields);
        $form->handle_upload('upload_additional', $fields);
        return $fields;
    },
    post_process => sub {
        my ($form) = @_;
        $form->process_upload('upload_insurance');
        $form->process_upload('upload_rams');
        $form->process_upload('upload_scaffold_drawing');
        $form->process_upload('upload_additional');
    },
);

has_field upload_insurance => (
    type => 'FileIdUpload',
    label => 'Public Liability Insurance certificate',
    tags => {
        hint => 'Minimum 10 million pound Public Liability Insurance',
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

has_field upload_scaffold_drawing => (
    type => 'FileIdUpload',
    label => 'Scaffold drawing',
    tags => {
        hint => 'Including measurements and available space maintained for pedestrians',
    },
    messages => {
        upload_file_not_found => 'Please upload a scaffold drawing',
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
);

has_field payment_transaction_id => (
    type => 'Text',
    label => 'Enter the transaction ID from your payment below',
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
