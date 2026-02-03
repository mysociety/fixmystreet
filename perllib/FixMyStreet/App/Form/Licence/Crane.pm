package FixMyStreet::App::Form::Licence::Crane;

use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Licence';
use utf8;

# Type identifier used in URL: /licence/crane
sub type { 'crane' }

# Human-readable name for display
sub name { 'Crane' }

sub next_after_contractor { 'details' }

# ==========================================================================
# Introduction / Before you get started
# ==========================================================================
has_page intro => (
    fields => ['start'],
    title => 'Crane Licence Application',
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
        hint => 'For example, "crane oversailing the public highway" or "overnight lift for building construction"',
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
    fields => ['carriageway_incursion', 'foundations', 'continue'],
    title => 'Carriageway impact',
    next => 'site_infrastructure',
);

has_field carriageway_incursion => (
    type => 'Text',
    label => 'What is the proposed carriageway incursion?',
    required => 1,
    tags => {
        hint => 'For example, "no carriageway incursion" or "temporary carriageway closure for crane lift"',
    },
);

has_field foundations => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Will the crane foundations / outriggers be located on the highway?',
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
    next => 'pre_application',
);

has_field site_obstruct_infrastructure => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Will the crane or the loads it is lifting obstruct or obscure any of the following: traffic signals, signal controllers, bus stops, pedestrian crossings, junction sight lines, road lighting columns, traffic signs, parking bays, ironwork in the highway, or other street furniture?',
    tags => { hint => 'If yes, a site meeting between the applicant and TfL may be required.' },
    required => 1,
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

# ==========================================================================
has_page pre_application => (
    fields => ['buses_consulted', 'underground_consulted', 'police_consulted', 'preapp_comments', 'continue'],
    title => 'Pre-application consultation',
    next => 'lifting',
);

has_field buses_consulted => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Have TfL Buses been consulted on the proposed works?',
    required => 1,
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

has_field underground_consulted => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Have TfL London Underground – Infrastructure Protection been consulted on the proposed works?',
    required => 1,
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

has_field police_consulted => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Have the Metropolitan Police - Safer Transport Teams been consulted on the proposed works?',
    required => 1,
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

has_field preapp_comments => (
    type => 'Text',
    widget => 'Textarea',
    label => 'Please provide any relevant comments relating to the pre-application consultation in the section below:',
    required => 1,
    tags => {
        hint => 'For example, "crane oversailing the public highway" or "overnight lift for building construction"',
    },
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
    label => 'Will any lifting be taking place to or from the public highway from a fixed crane?',
    tags => { hint => 'If yes, then a Crane (Lift) licence will be required. For vehicular plant hoisting detachable loads from one location to another please refer to our Mobile Cranes process.' },
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
    fields => ['crane_type', 'continue'],
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
    intro => 'crane/have_you_considered.html',
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
        'upload_additional',
        'continue'
    ],
    title => 'Upload required documents',
    intro => 'uploads.html',
    next => 'payment',
    update_field_list => sub {
        my ($form) = @_;
        my $fields = {};
        $form->handle_upload('upload_insurance', $fields);
        $form->handle_upload('upload_rams', $fields);
        $form->handle_upload('upload_site_drawing', $fields);
        $form->handle_upload('upload_additional', $fields);
        return $fields;
    },
    post_process => sub {
        my ($form) = @_;
        $form->process_upload('upload_insurance');
        $form->process_upload('upload_rams');
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


has_field upload_additional => (
    type => 'FileIdUpload',
    label => 'Additional supporting documentation',
    messages => {
        upload_file_not_found => 'Please upload any additional supporting documentation',
    },
);

sub payment_link {
    my $self = shift;
    my $type = $self->saved_data->{crane_type};
    if ($type eq 'Crane (Lift)') {
        return 'LIFT';
    } elsif ($type eq 'Crane (Oversail)') {
        return 'OVERSAIL';
    }
}

__PACKAGE__->meta->make_immutable;

1;
