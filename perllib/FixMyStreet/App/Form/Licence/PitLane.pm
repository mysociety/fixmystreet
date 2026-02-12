package FixMyStreet::App::Form::Licence::PitLane;

use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Licence';
use utf8;

# Type identifier used in URL: /licence/pit-lane
sub type { 'pit-lane' }

# Human-readable name for display
sub name { 'Pit Lane' }

sub next_after_contractor { 'activity' }

# ==========================================================================
# Introduction / Before you get started
# ==========================================================================
has_page intro => (
    fields => ['start'],
    title => 'Pit Lane Licence Application',
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
        hint => 'For example, "unloading materials for building refurbishment" or "removing waste from building demolition"',
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
    fields => ['carriageway_incursion', 'site_within_450mm', 'continue'],
    title => 'Carriageway impact',
    next => 'works',
);

has_field carriageway_incursion => (
    type => 'Text',
    label => 'What is the proposed carriageway incursion?',
    required => 1,
    tags => {
        hint => 'For example, "lane 1 closure to facilitate Pit Lane" or "loading bay closure for Pit Lane"',
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
has_page works => (
    fields => ['highway_works', 'section_278', 'continue'],
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

# ==========================================================================
has_page site_infrastructure => (
    fields => ['site_obstruct_infrastructure', 'sensitive_times', 'traffic_holds', 'continue'],
    title => 'Street infrastructure',
    next => 'pre_application',
);

has_field site_obstruct_infrastructure => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Will the pit lane obstruct or obscure any of the following: traffic signals, signal controllers, bus stops, pedestrian crossings, junction sight lines, road lighting columns, traffic signs, parking bays, ironwork in the highway, or other street furniture?',
    tags => { hint => 'If yes, a site meeting between the applicant and TfL may be required.' },
    required => 1,
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

has_field sensitive_times => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Will the Pit Lane occupy the highway during traffic sensitive times?',
    tags => { hint => 'If yes, a site meeting between the applicant and TfL may be required.' },
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
    next => 'type_check',
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
has_page type_check => (
    fields => ['significant_impact', 'bus_service_alterations', 'continue'],
    title => 'Pit Lane type',
    next => 'type',
    post_process => sub {
        my $form = shift;
        my $data = $form->saved_data;
        my $duration = $data->{proposed_duration};
        my $significant = $data->{significant_impact} || '';
        my $bus = $data->{bus_service_alterations} || '';
        if ($duration > 28 || $significant eq 'Yes' || $bus eq 'Yes') {
            $data->{pit_lane_type} = 'Pit Lane (Major)';
        }
    },
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
    fields => ['pit_lane_type', 'continue'],
    title => 'Pit Lane type',
    next => 'have_you_considered',
);

has_field pit_lane_type => (
    type => 'Select',
    widget => 'RadioGroup',
    label => "Pit Lane licence type",
    required => 1,
    options => [
        { label => 'Pit Lane (Minor)', value => 'Pit Lane (Minor)' },
        { label => 'Pit Lane (Major)', value => 'Pit Lane (Major)' },
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
    intro => 'pitlane/have_you_considered.html',
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
        $form->handle_upload('upload_traffic_management', $fields);
        $form->handle_upload('upload_additional', $fields);
        return $fields;
    },
    post_process => sub {
        my ($form) = @_;
        $form->process_upload('upload_insurance');
        $form->process_upload('upload_rams');
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

sub payment_link {
    my $self = shift;
    my $type = $self->saved_data->{pit_lane_type};
    if ($type eq 'Pit Lane (Major)') {
        return 'MAJOR';
    } else {
        return 'MINOR';
    }
}

__PACKAGE__->meta->make_immutable;

1;
