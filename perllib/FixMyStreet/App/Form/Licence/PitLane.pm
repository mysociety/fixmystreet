package FixMyStreet::App::Form::Licence::PitLane;

use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Licence::Base';
use utf8;

with 'FixMyStreet::App::Form::Licence::Fields::PreApplication';

# Type identifier used in URL: /licence/pit-lane
sub type { 'pit-lane' }

# Human-readable name for display
sub name { 'Pit Lane' }

sub tandc_link { 'https://content.tfl.gov.uk/pit-lane-guidance-notes-and-terms-conditions.pdf' }

sub next_after_contractor { 'activity' }

sub num_steps { 18 }

# ==========================================================================
# Introduction / Before you get started
# ==========================================================================
has_page intro => (
    fields => ['start'],
    title => 'Pit Lane licence application',
    intro => 'pitlane/intro.html',
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
    step_number => 1,
    fields => ['building_name_number', 'street_name', 'borough', 'postcode', 'continue'],
    title => 'Location of Pit Lane',
    intro => 'location.html',
    next => 'dates',
    post_process => sub {
        my $form = shift;
        $form->post_process_location;
    },
);

# ==========================================================================
# Times page, specially for pit lanes

has_page times => (
    step_number => 3,
    fields => ['proposed_start_time', 'proposed_end_time', 'continue'],
    title => 'Proposed working times',
    intro => 'pitlane/times.html',
    next => 'applicant',
);

has_field proposed_start_time => (
    type => 'Text',
    label => 'Proposed start time',
    required => 1,
);

has_field proposed_end_time => (
    type => 'Text',
    label => 'Proposed end time',
    required => 1,
);

# ==========================================================================
# Pit lane activity
# ==========================================================================
has_page activity => (
    step_number => 6,
    fields => ['activity', 'pit_lane_directly', 'continue'],
    title => 'Purpose of the pit lane',
    next => 'site_pedestrian_space',
);

has_field activity => (
    type => 'Text',
    widget => 'Textarea',
    label => 'What activity will the pit lane be used for?',
    required => 1,
    tags => {
        hint => 'For example, ‘unloading materials for building refurbishment’ or ‘removing waste from building demolition’',
    },
);

has_field pit_lane_directly => (
    type => 'Text',
    widget => 'Textarea',
    label => 'Explain why materials cannot be delivered directly into the site?',
    required => 1,
    tags => {
        hint => 'Note, there is a presumption against granting consent to pit lanes on London’s Red Routes; the preferred means of delivery of materials is directly into the construction site',
    },
);

# ==========================================================================
# Site Specific Information (pit lane-specific questions)
# Split into one question per page sometimes for better UX with long labels
# ==========================================================================
has_page site_pedestrian_space => (
    step_number => 7,
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
    step_number => 8,
    fields => ['carriageway_incursion', 'site_within_450mm', 'continue'],
    title => 'Carriageway impact',
    next => 'works',
);

has_field carriageway_incursion => (
    type => 'Text',
    label => 'What is the proposed carriageway incursion?',
    required => 1,
    tags => {
        hint => 'For example, ‘lane 1 closure to facilitate Pit Lane’ or ‘loading bay closure for Pit Lane’',
    },
);

has_field site_within_450mm => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Will any materials be stored within 450mm of the carriageway edge?',
    required => 1,
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

# ==========================================================================
has_page works => (
    step_number => 9,
    fields => ['highway_works', 'section_278', 'reference_section_278', 'continue'],
    title => 'Highway works',
    next => 'site_infrastructure',
);

has_field highway_works => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Are highway works or changes to the highway required in order to carry out the Pit Lane?',
    required => 1,
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

has_field section_278 => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Is there an existing Section 278 Agreement in place with TfL and what is the reference if so?',
    required => 1,
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

has_field reference_section_278 => (
    type => 'Text',
    label => 'Reference',
    required_when => { section_278 => 'Yes' },
    messages => { required => 'Please provide a reference for the Section 278 Agreement' },
);

# ==========================================================================
has_page site_infrastructure => (
    step_number => 10,
    fields => ['site_obstruct_infrastructure', 'continue'],
    title => 'Street infrastructure',
    next => 'pre_application',
);

has_field site_obstruct_infrastructure => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Will the pit lane obstruct or obscure any street furniture, such as traffic signals, crossings, or signs?',
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
    step_number => 11,
    fields => ['buses_consulted', 'underground_consulted', 'police_consulted', 'preapp_comments', 'continue'],
    title => 'Pre-application consultation',
    next => 'type_check',
);

# ==========================================================================
has_page type_check => (
    step_number => 12,
    fields => ['sensitive_times', 'traffic_holds', 'significant_impact', 'bus_service_alterations', 'continue'],
    title => 'Pit Lane impact',
    next => 'type',
    post_process => sub {
        my $form = shift;
        my $data = $form->saved_data;
        my $duration = $data->{proposed_duration};
        my $significant = $data->{significant_impact} || '';
        my $bus = $data->{bus_service_alterations} || '';
        if ($duration >= 28 || $significant eq 'Yes' || $bus eq 'Yes') {
            $data->{pit_lane_type} = 'Pit Lane (Major)';
        } else {
            $data->{pit_lane_type} = 'Pit Lane (Minor)';
        }

    },
);

has_field sensitive_times => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Will the Pit Lane occupy the highway during traffic sensitive times?',
    required => 1,
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

has_field traffic_holds => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Will any temporary traffic holds be required during deliveries?',
    required => 1,
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

has_field significant_impact => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Is there likely to be a significant impact to traffic flow due to a reduction in lane capacity in a traffic sensitive location?',
    required => 1,
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

has_field bus_service_alterations => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Are any bus service alterations required such as temporary bus stop suspensions or service changes?',
    required => 1,
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

# ==========================================================================
has_page type => (
    step_number => 13,
    fields => ['pit_lane_type', 'continue'],
    title => 'Pit Lane type',
    intro => 'pitlane/type.html',
    next => 'have_you_considered',
);

has_field pit_lane_type => (
    type => 'Select',
    widget => 'RadioGroup',
    label => "Pit Lane licence type",
    required => 1,
);

sub options_pit_lane_type {
    my $self = shift;
    my $data = $self->form->saved_data;
    my $disabled_minor = 0;

    my $duration = $data->{proposed_duration};
    my $significant = $data->{significant_impact} || '';
    my $bus = $data->{bus_service_alterations} || '';
    if ($duration >= 28 || $significant eq 'Yes' || $bus eq 'Yes') {
        $disabled_minor = 1;
    }
    return (
        { label => 'Pit Lane (Minor)', value => 'Pit Lane (Minor)', disabled => $disabled_minor },
        { label => 'Pit Lane (Major)', value => 'Pit Lane (Major)' },
    );
}

# ==========================================================================
# Have you considered? (TCSR/TTRO + T&Cs)
# Fields from Fields::TemporaryProhibition role
# ==========================================================================
has_page have_you_considered => (
    step_number => 14,
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
    intro => 'pitlane/have_you_considered.html',
    next => 'terms',
);

has_page terms => (
    step_number => 15,
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
    'upload_traffic_management',
    'upload_additional',
    'continue'
];
has_page uploads => (
    step_number => 16,
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

has_field upload_traffic_management => (
    type => 'FileIdUpload',
    label => 'Traffic Management plan',
    messages => {
        upload_file_not_found => 'Please upload a traffic management plan',
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
    my $type = $form->saved_data->{pit_lane_type};
    return $type eq 'Pit Lane (Major)' ? 'major' : 'minor';
}

__PACKAGE__->meta->make_immutable;

1;
