package FixMyStreet::App::Form::Licence::TemporaryTrafficSigns;

use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Licence::Base';
use utf8;

# Type identifier used in URL: /licence/temporary-traffic-signs
sub type { 'temporary-traffic-signs' }

# Human-readable name for display
sub name { 'Temporary Traffic Signs' }

sub tandc_link { 'https://content.tfl.gov.uk/temporary-traffic-signs-guidance-notes-and-terms-conditions.pdf' }

sub next_after_applicant { 'activity' }

# ==========================================================================
# Introduction / Before you get started
# ==========================================================================
has_page intro => (
    fields => ['start'],
    title => 'Temporary Traffic Signs licence application',
    intro => 'temporary-traffic-signs/intro.html',
    next => 'location_1',
);

has_field start => (
    type => 'Submit',
    value => 'Start application',
    element_attr => { class => 'govuk-button' },
);

# ==========================================================================
# Location (fields from Fields::Location role)
# ==========================================================================
has_page location_1 => (
    fields => ['building_name_number', 'street_name', 'borough', 'postcode', 'add_another', 'continue'],
    title => 'Location of the temporary traffic signs',
    intro => 'location.html',
    next => sub { $_[1]->{add_another} ? 'location_2' : 'dates' },
    post_process => sub {
        my $form = shift;
        $form->post_process_location;
    },
);

for my $page (2..10) {
    my $next = 'dates';
    my $fields = ["building_name_number_$page", "street_name_$page", "borough_$page", "postcode_$page", 'continue'];
    if ($page < 10) {
        $next = sub { $_[1]->{add_another} ? 'location_' . ($page+1) : 'dates' };
        push @$fields, 'add_another';
    }
    has_page "location_$page" => (
        fields => $fields,
        title => "Location of the temporary traffic signs ($page)",
        intro => 'location.html',
        next => $next,
        tags => { hide => sub { !$_[0]->form->saved_data->{"building_name_number_$page"} } },
    );
    has_field "building_name_number_$page" => ( type => 'Text', label => 'Building name / number', required => 1 );
    has_field "street_name_$page" => ( type => 'Text', label => 'Street name', required => 1 );
    has_field "borough_$page" => ( type => 'Text', label => 'Borough', required => 1 );
    has_field "postcode_$page" => ( type => 'Text', label => 'Postcode', required => 1 );
}

has_field 'add_another' => (
    type => 'Submit',
    value => 'Add another',
    element_attr => {
        class => 'govuk-button govuk-button--secondary',
    },
);

# ==========================================================================
# Activity/Sign Contents
# ==========================================================================
has_page activity => (
    fields => ['activity', 'sign_contents', 'site_existing_direction_signs', 'continue'],
    title => 'Purpose of the temporary traffic signs',
    next => 'installation',
);

has_field activity => (
    type => 'Text',
    widget => 'Textarea',
    label => 'What is the activity for which the licence is requested?',
    required => 1,
    tags => {
        hint => 'For example, ‘temporary traffic signs for county fair’',
    },
);

has_field sign_contents => (
    type => 'Text',
    widget => 'Textarea',
    label => 'What will be shown on the sign/s?',
    required => 1,
    tags => {
        hint => 'We also require an example of the proposed graphic as part of the application',
    },
);

has_field site_existing_direction_signs => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Are direction signs already provided to the venue?',
    tags => { hint => 'If yes, then a site meeting between the applicant and TfL will be required.' },
    required => 1,
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

# ==========================================================================
# Installation method
# ==========================================================================
has_page installation => (
    fields => ['installation_method', 'site_direct_illumination', 'site_use_tfl_electricity', 'continue'],
    title => 'Installation',
    next => 'site_pedestrian_space',
);

has_field installation_method => (
    type => 'Text',
    label => 'How will the sign/s be installed?',
    required => 1,
    tags => {
        hint => 'For example, ‘mobile elevating work platform’ or ‘cherry picker’. Note, a separate mobile apparatus application may also be required',
    },
);

has_field site_direct_illumination => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Will any signs be directly illuminated?',
    tags => { hint => 'If yes, then a site meeting between the applicant and TfL will be required.' },
    required => 1,
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

has_field site_use_tfl_electricity => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Will you be expecting to draw electrical energy from TfL’s lighting stock?',
    tags => { hint => 'If yes, then a site meeting between the applicant and TfL will be required.' },
    required => 1,
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);


# ==========================================================================
# Site Specific Information
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
    fields => ['carriageway_incursion', 'continue'],
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


# ==========================================================================
has_page site_infrastructure => (
    fields => ['site_obstruct_infrastructure', 'continue'],
    title => 'Street infrastructure',
    next => 'have_you_considered',
);

has_field site_obstruct_infrastructure => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Will the sign/s obstruct or obscure any street furniture, such as traffic signals, crossings, or signs?',
    tags => { hint => 'Other examples (not limited to) include bus stops, traffic signal controllers, lighting columns, parking bays, and ironwork.' },
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
        'tcsr_website_note',
        'continue'
    ],
    title => 'Additional considerations',
    intro => 'temporary-traffic-signs/have_you_considered.html',
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
    'upload_map',
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

has_field upload_map => (
    type => 'FileIdUpload',
    label => 'Map showing the location of each sign',
    tags => {
        hint => 'Including measurements and available space maintained for pedestrians',
    },
    messages => {
        upload_file_not_found => 'Please upload a map',
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
    my $weeks = $form->saved_data->{proposed_duration};
    return $weeks == 4 ? 'four' : 'default';
}

__PACKAGE__->meta->make_immutable;

1;
