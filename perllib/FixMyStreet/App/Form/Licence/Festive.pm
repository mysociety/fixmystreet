package FixMyStreet::App::Form::Licence::Festive;

use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Wizard';
use utf8;

# Shared field roles
with 'FixMyStreet::App::Form::Licence::Fields::Location';
with 'FixMyStreet::App::Form::Licence::Fields::Dates';
with 'FixMyStreet::App::Form::Licence::Fields::Applicant';
with 'FixMyStreet::App::Form::Licence::Fields::Contractor';
with 'FixMyStreet::App::Form::Licence::Fields::TemporaryProhibition';

# Type identifier used in URL: /licence/festive
sub type { 'festive' }

# Human-readable name for display
sub name { 'Festive Decoration' }

has upload_subdir => ( is => 'ro', default => 'tfl_licence_festive_files' );

has default_page_type => ( is => 'ro', isa => 'Str', default => 'Wizard' );

has finished_action => ( is => 'ro', default => 'process_licence' );

has '+is_html5' => ( default => 1 );

# ==========================================================================
# Introduction / Before you get started
# ==========================================================================
has_page intro => (
    fields => ['start'],
    title => 'Festive Decoration Licence Application',
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
    intro => 'festive/applicant.html',
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
        'contractor_authorised',
        'continue'
    ],
    title => 'Contractor details (Principal Contractor)',
    next => 'activity',
);

has_field contractor_authorised => (
    type => 'Checkbox',
    label => '',
    option_label => 'I confirm that I am authorised on behalf of the principal contractor named in this application and have been granted full written authority to submit this application on their behalf. I further confirm that all liabilities, insurance requirements, safety obligations, and statutory responsibilities remain with the principal contractor, and that all information supplied has been provided with their consent.',
    validate_method => sub {
        my $self = shift;
        my $same = $self->form->field('contractor_same_as_applicant')->value;
        $self->add_error('Please confirm') if !$self->value && !$same;
    },
    tags => { hide => sub { $_[0]->form->saved_data->{contractor_same_as_applicant} } },
);

# ==========================================================================
# Activity
# ==========================================================================
has_page activity => (
    fields => ['licence_activity', 'shown_decorations', 'how_configured', 'continue'],
    title => 'Purpose of the licence',
    next => 'site_pedestrian_space',
);

has_field licence_activity => (
    type => 'Text',
    widget => 'Textarea',
    label => 'What activity will the licence be used for?',
    required => 1,
    tags => {
        hint => 'For example, “seasonal decorations attached to lamp columns”',
    },
);

has_field shown_decorations => (
    type => 'Text',
    label => 'What will be shown on the festive decorations? We also require an example of the proposed decorations as part of the application.',
    required => 1,
    tags => {
        hint => 'For example, “illuminated Christmas trees”',
    },
);

has_field how_configured => (
    type => 'Text',
    label => "How will the decorations be installed?",
    required => 1,
    tags => {
        hint => 'For example, “mobile elevating work platform” or “cherry picker”. Note, a separate mobile apparatus application may also be required',
    },
);

# ==========================================================================
# Site Specific Information (licence-specific questions)
# Split into one question per page sometimes for better UX with long labels
# ==========================================================================
has_page site_pedestrian_space => (
    fields => ['footway_incursion', 'site_adequate_space', 'continue'],
    title => 'Pedestrian space',
    next => 'site_carriageway',
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
has_page site_carriageway => (
    fields => ['carriageway_incursion', 'continue'],
    title => 'Carriageway impact',
    next => 'site_specific_one',
);

has_field carriageway_incursion => (
    type => 'Text',
    label => 'What is the proposed carriageway incursion?',
    required => 1,
    tags => {
        hint => 'For example, "no carriageway incursion" or "temporary mobile lane closure for installation"',
    },
);

# ==========================================================================
has_page site_specific_one => (
    fields => ['code_of_practice', 'electrical_energy', 'continue'],
    title => 'Carriageway impact',
    next => 'site_infrastructure',
);

has_field code_of_practice => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Have you read and understood the CSS Seasonal Decorations Code of Practice?',
    required => 1,
    tags => { hint => FixMyStreet::Template::SafeString->new('Please read the <a href="https://theilp.org.uk/resources/" target="_blank">Code of Practice</a>. If yes, then a site meeting between the applicant and TfL may be required.') },
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

has_field electrical_energy => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Will you be expecting to draw electrical energy from TfL’s lighting stock?',
    required => 1,
    tags => { hint => 'If yes, then a site meeting between the applicant and TfL may be required.' },
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
    label => 'Will any decorations obstruct or obscure any of the following: traffic signal, traffic signal controller, bus stop, pedestrian crossing, junction sight line, road lighting column, traffic sign, parking bay, or any ‘ironwork’ in the highway or other street furniture?',
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
    intro => 'festive/have_you_considered.html',
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
# Upload required documents (licence-specific)
# ==========================================================================
has_page uploads => (
    fields => [
        'upload_insurance',
        'upload_rams',
        'upload_site_drawing',
        'upload_structural_testing',
        'upload_additional',
        'continue'
    ],
    title => 'Upload required documents',
    intro => 'festive/uploads.html',
    next => 'payment',
    update_field_list => sub {
        my ($form) = @_;
        my $fields = {};
        $form->handle_upload('upload_insurance', $fields);
        $form->handle_upload('upload_rams', $fields);
        $form->handle_upload('upload_site_drawing', $fields);
        $form->handle_upload('upload_structural_testing', $fields);
        $form->handle_upload('upload_additional', $fields);
        return $fields;
    },
    post_process => sub {
        my ($form) = @_;
        $form->process_upload('upload_insurance');
        $form->process_upload('upload_rams');
        $form->process_upload('upload_site_drawing');
        $form->process_upload('upload_structural_testing');
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

has_field upload_rams => (
    type => 'FileIdUpload',
    label => 'Risk Assessment Method Statement (RAMS)',
    messages => {
        upload_file_not_found => 'Please upload your Risk Assessment Method Statement',
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
