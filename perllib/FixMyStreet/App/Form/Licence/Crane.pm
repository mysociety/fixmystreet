package FixMyStreet::App::Form::Licence::Crane;

use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Licence::Base';
use utf8;

with 'FixMyStreet::App::Form::Licence::Fields::PreApplication';

# Type identifier used in URL: /licence/crane
sub type { 'crane' }

# Human-readable name for display
sub name { 'Crane' }

sub tandc_link { 'https://content.tfl.gov.uk/crane-guidance-notes-and-terms-conditions.pdf' }

sub next_after_contractor { 'details' }

# ==========================================================================
# Introduction / Before you get started
# ==========================================================================
has_page intro => (
    fields => ['start'],
    title => 'Crane licence application',
    intro => 'crane/intro.html',
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
    title => 'Location of the crane',
    intro => 'location.html',
    next => 'dates',
    post_process => sub {
        my $form = shift;
        $form->post_process_location;
    },
);

# ==========================================================================
# Crane details
# ==========================================================================
has_page details => (
    fields => ['model', 'weight', 'footprint', 'capacity', 'continue'],
    title => 'Crane details',
    next => 'activity',
);

has_field model => (
    type => 'Text',
    label => 'Model/Make',
    required => 1,
);

has_field weight => (
    type => 'Text',
    label => 'Weight (Tonnes)',
    required => 1,
    tags => { number => 1 },
    validate_method => sub {
        my $self = shift;
        return if $self->has_errors; # Called even if already failed
        $self->add_error('Please provide a number') unless $self->value =~ /^\d+(\.\d+)?$/;
    },
);

has_field footprint => (
    type => 'Text',
    label => 'Footprint dimensions',
    required => 1,
);

has_field capacity => (
    type => 'Text',
    label => 'Capacity (Tonnes)',
    required => 1,
    tags => { number => 1 },
    validate_method => sub {
        my $self = shift;
        return if $self->has_errors; # Called even if already failed
        $self->add_error('Please provide a number') unless $self->value =~ /^\d+(\.\d+)?$/;
    },
);

# ==========================================================================
# Crane activity
# ==========================================================================
has_page activity => (
    fields => ['activity', 'load', 'continue'],
    title => 'Purpose of the crane',
    next => 'site_pedestrian_space',
);

has_field activity => (
    type => 'Text',
    widget => 'Textarea',
    label => 'What activity will the crane be used for?',
    required => 1,
    tags => {
        hint => 'For example, ‘crane oversailing the public highway’ or ‘overnight lift for building construction’',
    },
);

has_field load => (
    type => 'Text',
    widget => 'Textarea',
    label => 'Details of loads being lifted (if applicable)',
    tags => {
        hint => 'Note, for vehicular plant hoisting detachable loads from one location to another, please use our Mobile Cranes licence',
    },
);

# ==========================================================================
# Site Specific Information (crane-specific questions)
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
    fields => ['carriageway_incursion', 'foundations', 'continue'],
    title => 'Carriageway impact',
    next => 'site_infrastructure',
);

has_field carriageway_incursion => (
    type => 'Text',
    label => 'What is the proposed carriageway incursion?',
    required => 1,
    tags => {
        hint => 'For example, ‘no carriageway incursion’ or ‘temporary carriageway closure for crane lift’',
    },
);

has_field foundations => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Will the crane foundations / outriggers be located on the highway?',
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
    next => 'pre_application',
);

has_field site_obstruct_infrastructure => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Will the crane or the loads it is lifting obstruct or obscure any street furniture, such as traffic signals, crossings, or signs?',
    tags => { hint => 'Other examples (not limited to) include bus stops, traffic signal controllers, lighting columns, parking bays, and ironwork.' },
    required => 1,
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

# ==========================================================================
# Fields provided by PreApplication role
has_page pre_application => (
    fields => ['buses_consulted', 'underground_consulted', 'police_consulted', 'preapp_comments', 'continue'],
    title => 'Pre-application consultation',
    next => 'lifting',
);

# ==========================================================================
has_page lifting => (
    fields => ['lifting', 'continue'],
    title => 'Crane lifting',
    next => 'type',
);

has_field lifting => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Will any lifting be taking place to or from the public highway using a fixed crane?',
    tags => {
        hint => FixMyStreet::Template::SafeString->new(
            'If yes, then a Crane (Lift) licence will be required. If no, then a Crane (Oversail) licence will apply for the crane oversailing the public highway only.<br><br>For vehicular plant hoisting detachable loads from one location to another, please refer to our Mobile Cranes process.'
        ),
    },
    required => 1,
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
    validate_method => sub {
        my $self = shift;
        return if $self->has_errors; # Called even if already failed

        if ($self->value eq 'Yes') {
            my $saved_data = $self->form->saved_data;
            $saved_data->{crane_type} = 'Crane (Lift)';
        }
    },
);

# ==========================================================================
has_page type => (
    fields => ['crane_type', 'crane_type_explanation', 'continue'],
    title => 'Crane type',
    next => 'have_you_considered',
);

has_field crane_type => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Crane licence type applied for',
    required => 1,
);

sub options_crane_type {
    my $self = shift;
    my $data = $self->form->saved_data;
    my ($disabled_lift, $disabled_oversail) = (0, 0);
    if ($data->{lifting} eq 'Yes') {
        $disabled_oversail = 1;
    }
    return (
        { label => 'Crane (Lift)', value => 'Crane (Lift)', disabled => $disabled_lift },
        { label => 'Crane (Oversail)', value => 'Crane (Oversail)', disabled => $disabled_oversail },
    );
}

has_field crane_type_explanation => (
    type  => 'Notice',
    label =>
        'Crane (Lift) — For lifting operations to or from the public highway.<br>Crane (Oversail) — For cranes oversailing the public highway without lifting to/from it.<br><br>You must ensure you select the correct crane licence type for the activity being carried out. Selecting the incorrect licence type may invalidate the licence and could make you liable to prosecution under the Highways Act 1980.',
    required => 0,
    widget   => 'NoRender',
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
    intro => 'crane/have_you_considered.html',
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
# Upload required documents (licence-specific)
# ==========================================================================
my $upload_fields = [
    'upload_insurance',
    'insurance_validity',
    'upload_rams',
    'upload_site_drawing',
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


has_field upload_additional => (
    type => 'FileIdUpload',
    label => 'Additional supporting documentation',
    messages => {
        upload_file_not_found => 'Please upload any additional supporting documentation',
    },
);

sub payment_link_key {
    my $form = shift;
    my $type = $form->saved_data->{crane_type};
    return 'lift' if $type eq 'Crane (Lift)';
    return 'oversail' if $type eq 'Crane (Oversail)';
}

__PACKAGE__->meta->make_immutable;

1;
