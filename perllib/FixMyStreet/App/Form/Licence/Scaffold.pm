package FixMyStreet::App::Form::Licence::Scaffold;

use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Wizard';
use utf8;

# Core licence functionality (upload handling, display methods)
with 'FixMyStreet::App::Form::Licence';

# Standard user fields (name, email, phone)
with 'FixMyStreet::App::Form::AboutYou';

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

has default_page_type => ( is => 'ro', isa => 'Str', default => 'Wizard' );

has finished_action => ( is => 'ro', default => 'process_licence' );

has '+is_html5' => ( default => 1 );

# Required by AboutYou role
has email_hint => ( is => 'ro', default => "We'll only use this to send you updates on your application" );
has phone_hint => ( is => 'ro', default => 'Telephone number for contact during office hours (9am-5pm)' );

before _process_page_array => sub {
    my ($self, $pages) = @_;
    foreach my $page (@$pages) {
        $page->{type} = $self->default_page_type
            unless $page->{type};
    }
};

# Add some functions to the form to pass through to the current page
has '+current_page' => (
    handles => {
        intro_template => 'intro',
        title => 'title',
        template => 'template',
    }
);

# ==========================================================================
# Page 1: Introduction / Before you get started
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
# Page 2: Location (fields from Fields::Location role)
# ==========================================================================
has_page location => (
    fields => ['street_name', 'building_name_number', 'borough', 'postcode', 'continue'],
    title => 'Location of the scaffolding',
    intro => 'location.html',
    next => 'dates',
    post_process => sub {
        my $form = shift;
        $form->post_process_location;
    },
);

# ==========================================================================
# Page 3: Dates (fields from Fields::Dates role)
# ==========================================================================
has_page dates => (
    fields => ['proposed_start_date', 'proposed_end_date', 'continue'],
    title => 'Period for which this application is made',
    intro => 'dates.html',
    next => 'applicant',
);

# ==========================================================================
# Page 4: About You (Applicant)
# Fields: organisation, address, phone_24h from Fields::Applicant role
# Fields: name, email, phone from AboutYou role
# ==========================================================================
has_page applicant => (
    fields => [
        'organisation',
        'name',
        'address',
        'email',
        'phone',
        'phone_24h',
        'continue'
    ],
    title => 'About you (Applicant)',
    next => 'contractor',
);

# ==========================================================================
# Page 5: About You (Principal Contractor)
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
        'continue'
    ],
    title => 'About you (Principal Contractor)',
    next => 'details',
);

# Scaffold-specific: NASC membership question
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

# ==========================================================================
# Page 6: Details of Scaffold / Activity (all scaffold-specific)
# ==========================================================================
has_page details => (
    fields => [
        'scaffold_height',
        'scaffold_length',
        'scaffold_width',
        'scaffold_activity',
        'scaffold_type',
        'footway_incursion',
        'carriageway_incursion',
        'continue'
    ],
    title => 'Details of scaffold',
    next => 'site_specific',
);

has_field scaffold_height => (
    type => 'Text',
    label => 'Height (metres)',
    required => 1,
);

has_field scaffold_length => (
    type => 'Text',
    label => 'Length (metres)',
    required => 1,
);

has_field scaffold_width => (
    type => 'Text',
    label => 'Width / Depth (metres)',
    required => 1,
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

has_field scaffold_type => (
    type => 'Text',
    label => 'What type of scaffold will be used?',
    required => 1,
    tags => {
        hint => 'For example, "independent", "gantry" or "mobile scaffold tower"',
    },
);

has_field footway_incursion => (
    type => 'Text',
    widget => 'Textarea',
    label => 'What is the proposed footway incursion?',
    required => 1,
    tags => {
        hint => 'For example, "1m from building line and 3m unobstructed footway" or "no footway incursion"',
    },
);

has_field carriageway_incursion => (
    type => 'Text',
    widget => 'Textarea',
    label => 'What is the proposed carriageway incursion?',
    required => 1,
    tags => {
        hint => 'For example, "no carriageway incursion" or "temporary lane closure for installation"',
    },
);

# ==========================================================================
# Page 7: Site Specific Information (scaffold-specific questions)
# ==========================================================================
has_page site_specific => (
    fields => [
        'site_adequate_space',
        'site_within_450mm',
        'site_obstruct_infrastructure',
        'site_protection_fan',
        'site_foundations_surveyed',
        'site_hoarding_attached',
        'site_trees_nearby',
        'continue'
    ],
    title => 'Site specific information',
    intro => 'scaffold/site_specific.html',
    next => 'have_you_considered',
);

has_field site_adequate_space => (
    type => 'Select',
    widget => 'RadioGroup',
    label => '1. Will adequate space be maintained for pedestrians as defined in section 4 of TfL’s Licensing Guidance, available from TfL’s Website i.e. 2m for lightly used footways, 3m for medium use footways, and 4 m for busy footways, with no reduction of width for intensely used footways?',
    required => 1,
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
        { label => 'N/A', value => 'N/A' },
    ],
);

has_field site_within_450mm => (
    type => 'Select',
    widget => 'RadioGroup',
    label => '2. Will any part of the scaffold be within 450mm of the edge of carriageway?',
    required => 1,
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
        { label => 'N/A', value => 'N/A' },
    ],
);

has_field site_obstruct_infrastructure => (
    type => 'Select',
    widget => 'RadioGroup',
    label => '3. Will the scaffolding obstruct or obscure any of the following: traffic signal, traffic signal controller, bus stop, pedestrian crossing, junction sight line, road lighting column, traffic sign, parking bay, or any ironwork in the highway or other street furniture?',
    required => 1,
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
        { label => 'N/A', value => 'N/A' },
    ],
);

has_field site_protection_fan => (
    type => 'Select',
    widget => 'RadioGroup',
    label => '4. Will a public protection fan and/or gantry be installed whilst the erection and dismantling of the scaffolding takes place?',
    required => 1,
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
        { label => 'N/A', value => 'N/A' },
    ],
);

has_field site_foundations_surveyed => (
    type => 'Select',
    widget => 'RadioGroup',
    label => '5. Have existing foundations been surveyed to ensure they are adequate to carry the loads imposed by the scaffolding structure?',
    required => 1,
    tags => {
        hint => 'If answer is no, what additional measures are intended? (Give details in scaffold plan)',
    },
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
        { label => 'N/A', value => 'N/A' },
    ],
);

has_field site_hoarding_attached => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Will a hoarding be attached to the scaffolding?',
    required => 1,
    tags => {
        hint => "6. If the answer is 'yes' there will also be a requirement for a separate hoarding application",
    },
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
        { label => 'N/A', value => 'N/A' },
    ],
);

has_field site_trees_nearby => (
    type => 'Select',
    widget => 'RadioGroup',
    label => '7. Are there any trees within falling distance of any part of the proposed scaffold?',
    required => 1,
    tags => {
        hint => "If answer is 'yes', then the application will be referred to the TfL Arboriculture & Landscape Manager for further consideration",
    },
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
        { label => 'N/A', value => 'N/A' },
    ],
);

# ==========================================================================
# Page 8: Have you considered? (TCSR/TTRO + T&Cs)
# Fields from Fields::TemporaryProhibition role
# ==========================================================================
has_page have_you_considered => (
    fields => [
        'parking_bay_suspension',
        'road_closure_required',
        'terms_accepted',
        'continue'
    ],
    title => 'Have you considered?',
    intro => 'have_you_considered.html',
    next => 'uploads',
);

# ==========================================================================
# Page 9: Upload required documents (scaffold-specific)
# ==========================================================================
has_page uploads => (
    fields => [
        'upload_insurance',
        'upload_rams',
        'upload_scaffold_drawing',
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
        return $fields;
    },
    post_process => sub {
        my ($form) = @_;
        $form->process_upload('upload_insurance');
        $form->process_upload('upload_rams');
        $form->process_upload('upload_scaffold_drawing');
    },
);

has_field upload_insurance => (
    type => 'FileIdUpload',
    label => 'Public Liability Insurance certificate',
    tags => {
        hint => 'Copy of your 10 million pound Public Liability Insurance',
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
        hint => 'Including measures and space maintained for pedestrians',
    },
    messages => {
        upload_file_not_found => 'Please upload a scaffold drawing',
    },
);

# ==========================================================================
# Page 10: Payment
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
    label => 'Transaction ID',
    tags => {
        hint => 'Enter the transaction ID from your payment',
    },
);

# ==========================================================================
# Page 11: Summary
# ==========================================================================
has_page summary => (
    fields => ['submit'],
    title => 'Check your answers',
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
# Page 12: Confirmation
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
