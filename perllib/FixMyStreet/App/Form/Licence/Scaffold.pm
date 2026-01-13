package FixMyStreet::App::Form::Licence::Scaffold;

use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Licence::Base';
use utf8;

# Type identifier used in URL: /licence/scaffold
sub type { 'scaffold' }

# Human-readable name for display
sub name { 'Scaffold' }

sub tandc_link { 'https://content.tfl.gov.uk/scaffold-guidance-notes-and-terms-conditions.pdf' }

sub next_after_applicant { 'dimensions' }

# ==========================================================================
# Introduction / Before you get started
# ==========================================================================
has_page intro => (
    fields => ['start'],
    title => 'Scaffold licence application',
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
# Scaffold dimensions
# ==========================================================================
has_page dimensions => (
    fields => ['scaffold_height', 'scaffold_length', 'scaffold_width', 'continue'],
    title => 'Scaffold dimensions',
    next => 'activity',
);

has_field scaffold_height => (
    type => 'Text',
    label => 'Height (metres)',
    required => 1,
    tags => { number => 1 },
    validate_method => sub {
        my $self = shift;
        return if $self->has_errors; # Called even if already failed
        $self->add_error('Please provide a number') unless $self->value =~ /^\d+(\.\d+)?$/;
    },
);

has_field scaffold_length => (
    type => 'Text',
    label => 'Length (metres)',
    required => 1,
    tags => { number => 1 },
    validate_method => sub {
        my $self = shift;
        return if $self->has_errors; # Called even if already failed

        my $length = $self->value;
        $self->add_error('Please provide a number') unless $length =~ /^\d+(\.\d+)?$/;

        my $saved_data = $self->form->saved_data;
        my $weeks = $saved_data->{proposed_duration};
        if ($weeks == 2) {
            $saved_data->{scaffold_type} = 'Scaffold (Mobile Tower)';
        } elsif ($length >= 10) {
            $saved_data->{scaffold_type} = 'Scaffold (Large)';
        } else {
            $saved_data->{scaffold_type} = 'Scaffold';
        }
    },
);

has_field scaffold_width => (
    type => 'Text',
    label => 'Width / Depth (metres)',
    required => 1,
    tags => { number => 1 },
    validate_method => sub {
        my $self = shift;
        return if $self->has_errors; # Called even if already failed
        $self->add_error('Please provide a number') unless $self->value =~ /^\d+(\.\d+)?$/;
    },
);

# ==========================================================================
# Scaffold activity
# ==========================================================================
has_page activity => (
    fields => ['activity', 'continue'],
    title => 'Purpose of the scaffold',
    next => 'site_pedestrian_space',
);

has_field activity => (
    type => 'Text',
    widget => 'Textarea',
    label => 'What activity will the scaffold be used for?',
    required => 1,
    tags => {
        hint => 'For example, ‘building repair’ or ‘window replacement’',
    },
);

# ==========================================================================
# Site Specific Information (scaffold-specific questions)
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
    label => 'Will any part of the scaffold be within 450mm of the carriageway edge?',
    required => 1,
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

# ==========================================================================
has_page site_infrastructure => (
    fields => ['site_obstruct_infrastructure', 'site_trees_nearby', 'site_tfl_structures', 'continue'],
    title => 'Street infrastructure',
    next => 'site_protection',
);

has_field site_obstruct_infrastructure => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Will the scaffold obstruct or obscure any street furniture, such as traffic signals, crossings, or signs?',
    tags => { hint => 'Other examples (not limited to) include bus stops, traffic signal controllers, lighting columns, parking bays, and ironwork.' },
    required => 1,
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

has_field site_trees_nearby => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Are any trees within falling distance of any part of the proposed scaffold?',
    required => 1,
    tags => {
        hint => "If yes, the application may be referred to the TfL Green Infrastructure team for further consideration and a site meeting with TfL may be required.",
    },
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

has_field site_tfl_structures => (
    type => 'Select',
    widget => 'RadioGroup',
    label =>
        'Are there any TfL structures or assets (including bridges, tunnels or buried infrastructure), whether visible or concealed, that could be affected by the proposed scaffold at any stage of its erection, use or dismantling?',
    required => 1,
    tags => {
        hint => "If yes, the application may be referred to the TfL Structures Technical Approvals team for further assessment, and a site meeting with TfL may be required.",
    },
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

# ==========================================================================
has_page site_protection => (
    fields => ['site_protection_fan', 'site_foundations_surveyed', 'continue'],
    title => 'Scaffold installation',
    next => 'site_hoarding',
);

has_field site_protection_fan => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Will a public protection fan and/or gantry be installed during the erection and dismantling of the scaffold?',
    required => 1,
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

has_field site_foundations_surveyed => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Have the existing foundations been assessed to ensure they are adequate to support the loads imposed by the scaffold structure?',
    required => 1,
    tags => {
        hint => 'If no, please specify what additional measures are proposed (details should be included in the scaffold plan).',
    },
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

# ==========================================================================
has_page site_hoarding => (
    fields => ['site_hoarding_attached', 'continue'],
    title => 'Hoarding',
    next => 'type',
);

has_field site_hoarding_attached => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Will a hoarding be attached to the scaffold?',
    required => 1,
    tags => {
        hint => "If yes, a separate hoarding application will be required.",
    },
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

# ==========================================================================
# Scaffold type
# ==========================================================================
has_page type => (
    fields => ['scaffold_type', 'scaffold_configured', 'continue'],
    title => 'Type of scaffold',
    intro => 'scaffold/type.html',
    next => 'have_you_considered',
);

has_field scaffold_type => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Scaffold type',
    required => 1,
);

sub options_scaffold_type {
    my $self = shift;
    my $data = $self->form->saved_data;
    my ($disabled_normal, $disabled_large, $disabled_mobile) = (0, 0, 0);
    if ($data->{proposed_duration} == 2) {
        $disabled_normal = 1;
        $disabled_large = 1;
    } elsif ($data->{scaffold_length} >= 10) {
        $disabled_normal = 1;
        $disabled_mobile = 1;
    } else {
        $disabled_large = 1;
        $disabled_mobile = 1;
    }
    return (
        { label => 'Scaffold', value => 'Scaffold', disabled => $disabled_normal,
            hint => 'A standard scaffold less than 10 metres in length' },
        { label => 'Scaffold (Large)', value => 'Scaffold (Large)', disabled => $disabled_large,
            hint => 'Any scaffold 10 metres or greater in length' },
        { label => 'Scaffold (Mobile Tower)', value => 'Scaffold (Mobile Tower)', disabled => $disabled_mobile,
            hint => 'For small mobile scaffold towers, only valid up to two weeks' },
    );
}

has_field scaffold_configured => (
    type => 'Text',
    label => 'How will the scaffold be configured?',
    required => 1,
    tags => {
        hint => 'For example, ‘independent’, ‘gantry’ or ‘cantilever’',
    },
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
    intro => 'scaffold/have_you_considered.html',
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
# Upload required documents (scaffold-specific)
# ==========================================================================
my $upload_fields = [
    'upload_insurance',
    'insurance_validity',
    'upload_rams',
    'upload_scaffold_drawing',
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

sub payment_link {
    my $self = shift;
    my $type = $self->saved_data->{scaffold_type};
    if ($type eq 'Scaffold (Mobile Tower)') {
        return 'https://ebc2test.cybersource.com/ebc2/payByLink/pay/rKoNGpTjrw8wwoygPdsmbNjiPhbCLr98MHR1B2xx9iazhSecgrT8mZziDEUnol6L';
    } elsif ($type eq 'Scaffold (Large)') {
        return 'https://ebc2test.cybersource.com/ebc2/payByLink/pay/mzWBnuiA747cclZIDar9r8jF5BConLNld6QWbfZJJfTViBsEggO0jpu68tI7DWMx';
    } else {
        return 'https://ebc2test.cybersource.com/ebc2/payByLink/pay/1S1H8aiH78NUYsz3863iSbn1Z7OdesWjzBLAo41i0alca5Q2uM9RPTF3NGYIK5WR';
    }
}

__PACKAGE__->meta->make_immutable;

1;
