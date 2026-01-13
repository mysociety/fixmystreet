package FixMyStreet::App::Form::Licence::MobileApparatus;

use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Licence::Base';
use utf8;

with 'FixMyStreet::App::Form::Licence::Fields::PreApplication';

# Type identifier used in URL
sub type { 'mobile-apparatus' }

# Human-readable name for display
sub name { 'Mobile apparatus' }

sub tandc_link { 'https://content.tfl.gov.uk/mobile-apparatus-guidance-notes-and-terms-conditions.pdf' }

sub next_after_contractor { 'details' }

# ==========================================================================
# Introduction / Before you get started
# ==========================================================================
has_page intro => (
    fields => ['start'],
    title => 'Mobile apparatus licence application',
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
    title => 'Number of mobile apparatus operations',
    next => sub {
        $_[0]->{date_choice} =~ /^dates/ ? 'dates_pick_1' : 'date_range_pick',
    },
);

has_field date_choice => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Select the number of operations you require',
    tags => {
        hint =>
            'Note, each operation is subject to a 24-hour time limit and anything beyond will be considered as a new operation. If more operations are required then multiple applications will be required.',
    },
    required => 1,
    options => [
        { label => '1 operation', value => 'dates_1' },
        { label => '2 operations', value => 'dates_2' },
        { label => '3 operations', value => 'dates_3' },
        { label => '7 operations (1 week continuous)', value => 'week' },
        { label => '14 operations (2 weeks continuous)', value => 'fortnight' },
    ],
);

has_page dates_pick_1 => (
    _dates_pick_attributes(1),
    next => sub { $_[0]->{date_choice} eq 'dates_1' ? 'applicant' : 'dates_pick_2' },
    tags => { hide => sub { !$_[0]->form->saved_data->{start_date_1} } },
);

has_page dates_pick_2 => (
    _dates_pick_attributes(2),
    next => sub { $_[0]->{date_choice} eq 'dates_2' ? 'applicant' : 'dates_pick_3' },
    tags => { hide => sub { !$_[0]->form->saved_data->{start_date_2} } },
);

has_page dates_pick_3 => (
    _dates_pick_attributes(3),
    next => 'applicant',
    tags => { hide => sub { !$_[0]->form->saved_data->{start_date_3} } },
);

sub _dates_pick_attributes {
    my $num = shift;

    return (
        fields => [
            "start_date_$num", "start_time_$num", "end_date_$num", "end_time_$num",
            'continue'
        ],
        title => "Proposed working dates (Operation $num) (subject to approval)",
    );
}

sub _date_field_attributes {
    my ( $num, $start_or_end ) = @_;

    return (
        type => 'DateTime',
        label => "Proposed $start_or_end date",
        required => 1,
        messages => {
            datetime_invalid => 'Please enter a valid date',
            required => "Proposed $start_or_end date is required",
        },
        validate_method => \&validate_date,
    );
}

sub _time_field_attributes { ( type => 'Text', label => "Proposed $_[0] time", required => 1 ) }

sub validate_date {
    my $field = shift;
    my $form = $field->form;
    return if $field->has_errors; # Called even if already failed

    my $dt = $field->value or return;
    my $today = DateTime->today(time_zone => FixMyStreet->local_time_zone);
    my $min_date = $today->clone->add(weeks => 4);

    if ($dt < $min_date) {
        $field->add_error('Date must be at least 4 weeks from today');
    }

    # If field is an end date, it must be same day or later than
    # start date.
    my $page_name = $form->current_page->name;
    $page_name =~ /dates_pick_(\d)/;
    if (   $1
        && $field->name eq "end_date_$1"
        && $field->value < $form->field("start_date_$1")->value )
    {
        $field->add_error(
            'End date must be same as or later than start date');
    }
}

# ==========================================================================
# Operation 1
# ==========================================================================

for my $page (1..3) {
    has_field "start_date_$page" => ( _date_field_attributes( $page, 'start' ) );
    has_field "start_date_$page.day" => ( type => 'MonthDay' );
    has_field "start_date_$page.month" => ( type => 'Month' );
    has_field "start_date_$page.year" => ( type => 'Year' );

    has_field "start_time_$page" => ( _time_field_attributes('start') );

    has_field "end_date_$page" => ( _date_field_attributes( $page, 'end' ) );
    has_field "end_date_$page.day" => ( type => 'MonthDay' );
    has_field "end_date_$page.month" => ( type => 'Month' );
    has_field "end_date_$page.year" => ( type => 'Year' );

    has_field "end_time_$page" => ( _time_field_attributes('end') );
}

has_page date_range_pick => (
    fields => ['proposed_start_date', 'calculated_end_date', 'proposed_start_time', 'proposed_end_time', 'continue'],
    title => 'Proposed working dates (subject to approval)',
    next => 'applicant',
    tags => { hide => sub { !$_[0]->form->saved_data->{proposed_start_date} } },
);

has_field proposed_start_date => (
    type => 'DateTime',
    label => 'Proposed start date',
    required => 1,
    messages => {
        datetime_invalid => 'Please enter a valid date',
    },
    validate_method => sub {
        my $field = shift;
        return if $field->has_errors; # Called even if already failed

        my $dt = $field->value or return;
        my $today = DateTime->today(time_zone => FixMyStreet->local_time_zone);
        my $min_date = $today->clone->add(weeks => 4);

        if ($dt < $min_date) {
            $field->add_error('Start date must be at least 4 weeks from today');
        }

        my $saved_data = $field->form->saved_data;
        my $end = $dt->clone;
        if ($saved_data->{date_choice} eq 'week') {
            $end->add(days => 6);
        } elsif ($saved_data->{date_choice} eq 'fortnight') {
            $end->add(days => 13);
        }
        $saved_data->{proposed_end_date} = $end;
    },
);

has_field 'proposed_start_date.day' => ( type => 'MonthDay' );
has_field 'proposed_start_date.month' => ( type => 'Month' );
has_field 'proposed_start_date.year' => ( type => 'Year' );

has_field calculated_end_date => (
    type  => 'Notice',
    build_label_method => sub {
        my $type = $_[0]->form->saved_data->{date_choice};
        my $days = $type eq 'week' ? 6 : 13;
        my $str = '<span id="js-proposed_end_date" data-days="' . $days . '"></span>';
        return $str;
    },
    required => 0,
    widget   => 'NoRender',
);

has_field proposed_start_time => ( _time_field_attributes('start') );
has_field proposed_end_time => ( _time_field_attributes('end') );

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
        hint => 'For example, ‘mobile elevated working platform for window replacement’ or ‘cherry picker to install column attachments’',
    },
);

# ==========================================================================
# Site Specific Information (licence-specific questions)
# Split into one question per page sometimes for better UX with long labels
# ==========================================================================
has_page site_pedestrian_space => (
    fields => ['footway_incursion', 'situated_on_footway', 'site_adequate_space', 'continue'],
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

has_field situated_on_footway => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Will the mobile apparatus be situated primarily on the footway?',
    required => 1,
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

# ==========================================================================
has_page site_carriageway_distance => (
    fields => ['carriageway_incursion', 'situated_on_carriageway', 'continue'],
    title => 'Carriageway impact',
    next => 'site_infrastructure',
);

has_field carriageway_incursion => (
    type => 'Text',
    label => 'What is the proposed carriageway incursion?',
    required => 1,
    tags => {
        hint => 'For example, ‘no carriageway incursion’ or ‘Materials located in loading bay’',
    },
);

has_field situated_on_carriageway => (
    type => 'Select',
    widget => 'RadioGroup',
    label =>
        'Will the mobile apparatus be situated on, or have any impact to the carriageway (e.g. requiring a lane closure)?',
    required => 1,
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

# ==========================================================================
has_page site_infrastructure => (
    fields => ['site_obstruct_infrastructure', 'load_bearing_assessment', 'continue'],
    title => 'Street infrastructure',
    next => 'pre_application',
);

has_field site_obstruct_infrastructure => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Will the mobile apparatus obstruct or obscure any street furniture, such as traffic signals, crossings, or signs?',
    tags => { hint => 'Other examples (not limited to) include bus stops, traffic signal controllers, lighting columns, parking bays, and ironwork.' },
    required => 1,
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

has_field load_bearing_assessment => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Has a load‑bearing assessment been completed for the ground where the mobile apparatus will operate?',
    tags => { hint => 'This is mandatory when operating on the footway.' },
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
    next => 'type',
    post_process => sub {
        my $form = shift;
        my $data = $form->saved_data;
        if ( $data->{situated_on_carriageway} eq 'Yes' ) {
            $data->{apparatus_type} = 'Mobile Apparatus (Carriageway)';
        } elsif ( $data->{situated_on_footway} eq 'Yes' ) {
            $data->{apparatus_type} = 'Mobile Apparatus (Footway)';
        }
    },
);

# ==========================================================================
# Type
# ==========================================================================
has_page type => (
    fields => ['apparatus_type', 'apparatus_type_notice', 'continue'],
    title => 'Mobile apparatus type',
    next => 'have_you_considered',
);

has_field apparatus_type => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Mobile apparatus type',
    required => 1,
);

sub options_apparatus_type {
    my $self = shift;
    my $data = $self->form->saved_data;

    my $disabled_footway = $data->{situated_on_carriageway} eq 'Yes' ? 1 : 0;

    return (
        {   label    => 'Mobile Apparatus (Footway)',
            value    => 'Mobile Apparatus (Footway)',
            disabled => $disabled_footway,
        },
        {   label => 'Mobile Apparatus (Carriageway)',
            value => 'Mobile Apparatus (Carriageway)',
        },
    );
}

has_field apparatus_type_notice => (
    type  => 'Notice',
    label =>
        'Based on your selections, the above Mobile Apparatus type will apply. A Mobile Apparatus (Footway) is only suitable for works not impacting live traffic, whereas a Mobile Apparatus (Carriageway) may require lane closures or road closures.',
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
    intro => 'mobile-apparatus/have_you_considered.html',
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
# Upload required documents
# ==========================================================================
my $upload_fields = [
    'upload_insurance',
    'insurance_validity',
    'upload_rams',
    'upload_site_drawing',
    'upload_traffic_management',
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
