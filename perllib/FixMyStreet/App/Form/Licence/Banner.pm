package FixMyStreet::App::Form::Licence::Banner;

use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Licence::Base';
use utf8;

# Type identifier used in URL: /licence/banner
sub type { 'banner' }

# Human-readable name for display
sub name { 'Banner' }

sub tandc_link { 'https://content.tfl.gov.uk/banners-guidance-notes-and-terms-conditions.pdf' }

sub next_after_contractor { 'type' }

# ==========================================================================
# Introduction / Before you get started
# ==========================================================================
has_page intro => (
    fields => ['start'],
    title => 'Banner licence application',
    intro => 'banner/intro.html',
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
    title => 'Location of the banner/s',
    intro => 'location.html',
    next => sub { $_[1]->{add_another} ? 'location_2' : 'dates' },
    post_process => sub {
        my $form = shift;
        $form->post_process_location;
    },
);

for my $page (2..5) {
    my $next = 'dates';
    my $fields = ["building_name_number_$page", "street_name_$page", "borough_$page", "postcode_$page", 'continue'];
    if ($page < 5) {
        $next = sub { $_[1]->{add_another} ? 'location_' . ($page+1) : 'dates' };
        push @$fields, 'add_another';
    }
    has_page "location_$page" => (
        fields => $fields,
        title => "Location of the Column Attachments ($page)",
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
# Extra questions
# ==========================================================================

# ==========================================================================
# Banner activity
# ==========================================================================
has_page type => (
    fields => ['banner_type', 'banner_content', 'continue'],
    title => 'Banner details',
    next => 'installation',
);

has_field banner_type => (
    type => 'Text',
    widget => 'Textarea',
    label => 'What type of banner will be put up?',
    required => 1,
    tags => {
        hint =>
            'For example, ‘Banners attached to lamp columns’, ‘Placards attached to pedestrian guard rail’ or ‘Banners secured between buildings and overhanging the highway’',
    },
);

has_field banner_content => (
    type => 'Text',
    widget => 'Textarea',
    label =>
        'What will be shown on the banner/s? We also require an example of the proposed graphic as part of the application',
    required => 1,
    tags => {
        hint =>
            'For example, ‘New Community Centre’ or ‘Major Sporting Event’',
    },
);

# ==========================================================================
has_page installation => (
    fields => ['banner_installation', 'continue'],
    title => 'Banner installation',
    next => 'site_pedestrian_space',
);

has_field banner_installation => (
    type => 'Text',
    widget => 'Textarea',
    label => 'How will the banner/s be installed?',
    required => 1,
    tags => {
        hint =>
            FixMyStreet::Template::SafeString->new('For example, ‘mobile elevating work platform’ or ‘cherry picker’.<br>Note: a separate mobile apparatus application may also be required'),
    },
);

# ==========================================================================
# Site Specific Information (banner-specific questions)
# ==========================================================================
has_page site_pedestrian_space => (
    fields => [ 'site_adequate_space', 'footway_incursion', 'footway_headroom',  'continue' ],
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
        hint =>
            'For example, ‘1m from building line and 3m unobstructed footway’ or ‘no footway incursion’',
    },
);

has_field footway_headroom => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Will the headroom over any footway be less than 2m?',
    required => 1,
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

# ==========================================================================
has_page site_carriageway_distance => (
    fields => ['carriageway_incursion', 'carriageway_headroom', 'continue'],
    title => 'Carriageway space',
    next => 'site_infrastructure',
);

has_field carriageway_incursion => (
    type => 'Text',
    label => 'What is the proposed carriageway incursion?',
    required => 1,
    tags => {
        hint =>
            'For example, ‘no carriageway incursion’ or ‘temporary lane closure for installation’',
    },
);

has_field carriageway_headroom => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Will the headroom over any carriageway be less than 6m?',
    required => 1,
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

# ==========================================================================
has_page site_infrastructure => (
    fields => [
        'site_ad_compliance', 'site_lighting_columns',
        'site_near_junction', 'site_obstruct_infrastructure',
        'continue'
    ],
    title => 'Street infrastructure',
    next  => 'have_you_considered',
);

has_field site_ad_compliance => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Does the banner/s comply with TfL’s advertising policy?',
    tags => {
        hint => FixMyStreet::Template::SafeString->new(
            'As found on <a href="https://tfl.gov.uk/corporate/publications-and-reports/commercial-media#on-this-page-3">TfL’s website</a>. If no, a site meeting between the applicant and TfL may be required.'
        ),
    },
    required => 1,
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

has_field site_lighting_columns => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Are any banners proposed to be attached to lighting columns?',
    required => 1,
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

has_field site_near_junction => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Will any banners attached to pedestrian guard rails be within 20m of a junction or a pedestrian crossing point?',
    required => 1,
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

has_field site_obstruct_infrastructure => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Will any banners obstruct or obscure any street furniture, such as traffic signals, crossings, or signs?',
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
    intro => 'banner/have_you_considered.html',
    next => 'terms',
);

# ==========================================================================
# T&Cs
# ==========================================================================
has_page terms => (
    fields => [
        'terms_accepted',
        'continue'
    ],
    title => 'Terms and conditions confirmation',
    next => 'uploads',
);

# ==========================================================================
# Upload required documents (banner-specific)
# ==========================================================================
my $upload_fields = [
    'upload_insurance',
    'insurance_validity',
    'upload_rams',
    'upload_map',
    'upload_structural_testing',
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
    label => 'Map showing the location of the each of the banners',
    messages => {
        upload_file_not_found => 'Please upload a map',
    },
);

has_field upload_structural_testing => (
    type => 'FileIdUpload',
    label => 'Structural testing',
    messages => {
        upload_file_not_found => 'Please upload a structural testing document',
    },
);

__PACKAGE__->meta->make_immutable;

1;
