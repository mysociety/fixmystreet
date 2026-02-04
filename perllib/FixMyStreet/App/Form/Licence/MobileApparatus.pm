package FixMyStreet::App::Form::Licence::MobileApparatus;

use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Licence';
use utf8;

# Type identifier used in URL
sub type { 'mobile-apparatus' }

# Human-readable name for display
sub name { 'Mobile apparatus' }

sub next_after_contractor { 'details' }

# ==========================================================================
# Introduction / Before you get started
# ==========================================================================
has_page intro => (
    fields => ['start'],
    title => 'Mobile apparatus Licence Application',
    intro => 'mobile-apparatus/intro.html',
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
    title => 'Location of mobile apparatus',
    intro => 'location.html',
    next => 'date_choice',
    post_process => sub {
        my $form = shift;
        $form->post_process_location;
    },
);

# ==========================================================================
# Date picker
# ==========================================================================

has_page date_choice => (
    fields => ['date_choice', 'continue'],
    title => 'Date option',
    next => sub {
        $_[0]->{date_choice} eq 'dates' ? 'dates_pick' : 'applicant',
    },
);

has_field date_choice => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Would you like one to three individual dates, or a 1 or 2 week continuous period?',
    required => 1,
    options => [
        { label => 'Individual dates', value => 'dates' },
        { label => '7 operations (1 week continuous)', value => 'week' },
        { label => '14 operations (2 weeks continuous)', value => 'fortnight' },
    ],
);

has_page dates_pick => (
    fields => [
        'date1', 'start_time1', 'end_time1',
        'date2', 'start_time2', 'end_time2',
        'date3', 'start_time3', 'end_time3',
        'continue'],
    title => 'Pick your dates',
    next => 'applicant',
    tags => {
        hide => sub {
            my $self = shift;
            my $data = $self->form->saved_data;
            return $data->{date_choice} ne 'dates';
        },
    },
);

sub validate_date {
    my $field = shift;
    return if $field->has_errors; # Called even if already failed

    my $dt = $field->value or return;
    my $today = DateTime->today(time_zone => FixMyStreet->local_time_zone);
    my $min_date = $today->clone->add(weeks => 4);

    if ($dt < $min_date) {
        $field->add_error('Date must be at least 4 weeks from today');
    }
}

has_field date1 => (
    type => 'DateTime',
    label => 'Operation 1',
    required => 1,
    messages => {
        datetime_invalid => 'Please enter a valid date',
    },
    validate_method => \&validate_date,
);
has_field 'date1.day' => ( type => 'MonthDay' );
has_field 'date1.month' => ( type => 'Month' );
has_field 'date1.year' => ( type => 'Year' );

has_field start_time1 => (
    type => 'Text',
    label => 'Proposed start time',
    required_when => { 'date1' => sub { $_[0] && ($_[0]->{day} || $_[0]->{month} || $_[0]->{year}) } },
);

has_field end_time1 => (
    type => 'Text',
    label => 'Proposed end time',
    required_when => { 'date1' => sub { $_[0] && ($_[0]->{day} || $_[0]->{month} || $_[0]->{year}) } },
);

has_field date2 => (
    type => 'DateTime',
    label => 'Operation 2',
    messages => {
        datetime_invalid => 'Please enter a valid date',
    },
    tags => { hint => 'Optional' },
    validate_method => \&validate_date,
);
has_field 'date2.day' => ( type => 'MonthDay' );
has_field 'date2.month' => ( type => 'Month' );
has_field 'date2.year' => ( type => 'Year' );

has_field start_time2 => (
    type => 'Text',
    label => 'Proposed start time',
    required_when => { 'date2' => sub { $_[0] && ($_[0]->{day} || $_[0]->{month} || $_[0]->{year}) } },
);

has_field end_time2 => (
    type => 'Text',
    label => 'Proposed end time',
    required_when => { 'date2' => sub { $_[0] && ($_[0]->{day} || $_[0]->{month} || $_[0]->{year}) } },
);

has_field date3 => (
    type => 'DateTime',
    label => 'Operation 3',
    messages => {
        datetime_invalid => 'Please enter a valid date',
    },
    tags => { hint => 'Optional' },
    validate_method => \&validate_date,
);
has_field 'date3.day' => ( type => 'MonthDay' );
has_field 'date3.month' => ( type => 'Month' );
has_field 'date3.year' => ( type => 'Year' );

has_field start_time3 => (
    type => 'Text',
    label => 'Proposed start time',
    required_when => { 'date3' => sub { $_[0] && ($_[0]->{day} || $_[0]->{month} || $_[0]->{year}) } },
);

has_field end_time3 => (
    type => 'Text',
    label => 'Proposed end time',
    required_when => { 'date3' => sub { $_[0] && ($_[0]->{day} || $_[0]->{month} || $_[0]->{year}) } },
);

# ==========================================================================
# Crane details
# ==========================================================================
has_page details => (
    fields => ['model', 'weight', 'footprint', 'capacity', 'continue'],
    title => 'Mobile apparatus details',
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
# Activity
# ==========================================================================
has_page activity => (
    fields => ['activity', 'continue'],
    title => 'Purpose of the mobile apparatus',
    next => 'site_pedestrian_space',
    intro => 'mobile-apparatus/activity.html',
);

has_field activity => (
    type => 'Text',
    widget => 'Textarea',
    label => 'What activity will the mobile apparatus be used for?',
    required => 1,
    tags => {
        hint => 'For example, “mobile elevated working platform for window replacement” or “cherry picker to install column attachments”',
    },
);

# ==========================================================================
# Site Specific Information (licence-specific questions)
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
        hint => 'For example, “no carriageway incursion” or “Materials located in loading bay”',
    },
);

has_field site_within_450mm => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Will any materials be stored within 450mm of the carriageway edge?',
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
    label => 'Will the materials obstruct or obscure any of the following: traffic signal, traffic signal controller, bus stop, pedestrian crossing, junction sight line, road lighting column, traffic sign, parking bay, or any ‘ironwork’ in the highway or other street furniture?',
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
    next => 'have_you_considered',
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
        hint => 'For example, “crane oversailing the public highway” or “overnight lift for building construction”',
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
        'continue'
    ],
    title => 'Additional considerations',
    intro => 'mobile-apparatus/have_you_considered.html',
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
# Upload required documents
# ==========================================================================
has_page uploads => (
    fields => [
        'upload_insurance',
        'upload_rams',
        'upload_site_drawing',
        'upload_traffic_management',
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
        $form->handle_upload('upload_traffic_management', $fields);
        $form->handle_upload('upload_additional', $fields);
        return $fields;
    },
    post_process => sub {
        my ($form) = @_;
        $form->process_upload('upload_insurance');
        $form->process_upload('upload_rams');
        $form->process_upload('upload_site_drawing');
        $form->process_upload('upload_traffic_management');
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

has_field upload_traffic_management => (
    type => 'FileIdUpload',
    label => 'Traffic Management plan',
    messages => {
        upload_file_not_found => 'Please upload a Traffic Management plan',
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
