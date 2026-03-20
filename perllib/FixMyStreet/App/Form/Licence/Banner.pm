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

has_page location_2 => (
    fields => ['building_name_number_2', 'street_name_2', 'borough_2', 'postcode_2', 'add_another', 'continue'],
    title => 'Location of the Column Attachments (2)',
    intro => 'location.html',
    next => sub { $_[1]->{add_another} ? 'location_3' : 'dates' },
    tags => { hide => sub { !$_[0]->form->saved_data->{building_name_number_2} } },
);
has_field building_name_number_2 => ( type => 'Text', label => 'Building name / number', required => 1 );
has_field street_name_2 => ( type => 'Text', label => 'Street name', required => 1 );
has_field borough_2 => ( type => 'Text', label => 'Borough', required => 1 );
has_field postcode_2 => ( type => 'Text', label => 'Postcode', required => 1 );

has_page location_3 => (
    fields => ['building_name_number_3', 'street_name_3', 'borough_3', 'postcode_3', 'add_another', 'continue'],
    title => 'Location of the Column Attachments (3)',
    intro => 'location.html',
    next => sub { $_[1]->{add_another} ? 'location_4' : 'dates' },
    tags => { hide => sub { !$_[0]->form->saved_data->{building_name_number_3} } },
);
has_field building_name_number_3 => ( type => 'Text', label => 'Building name / number', required => 1 );
has_field street_name_3 => ( type => 'Text', label => 'Street name', required => 1 );
has_field borough_3 => ( type => 'Text', label => 'Borough', required => 1 );
has_field postcode_3 => ( type => 'Text', label => 'Postcode', required => 1 );

has_page location_4 => (
    fields => ['building_name_number_4', 'street_name_4', 'borough_4', 'postcode_4', 'add_another', 'continue'],
    title => 'Location of the Column Attachments (4)',
    intro => 'location.html',
    next => sub { $_[1]->{add_another} ? 'location_5' : 'dates' },
    tags => { hide => sub { !$_[0]->form->saved_data->{building_name_number_4} } },
);
has_field building_name_number_4 => ( type => 'Text', label => 'Building name / number', required => 1 );
has_field street_name_4 => ( type => 'Text', label => 'Street name', required => 1 );
has_field borough_4 => ( type => 'Text', label => 'Borough', required => 1 );
has_field postcode_4 => ( type => 'Text', label => 'Postcode', required => 1 );

has_page location_5 => (
    fields => ['building_name_number_5', 'street_name_5', 'borough_5', 'postcode_5', 'continue'],
    title => 'Location of the Column Attachments (5)',
    intro => 'location.html',
    next => 'dates',
    tags => { hide => sub { !$_[0]->form->saved_data->{building_name_number_5} } },
);
has_field building_name_number_5 => ( type => 'Text', label => 'Building name / number', required => 1 );
has_field street_name_5 => ( type => 'Text', label => 'Street name', required => 1 );
has_field borough_5 => ( type => 'Text', label => 'Borough', required => 1 );
has_field postcode_5 => ( type => 'Text', label => 'Postcode', required => 1 );

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
    fields => [
        'footway_incursion', 'site_adequate_space',
        'footway_headroom',  'continue'
    ],
    title => 'Pedestrian space',
    next => 'site_carriageway_distance',
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

has_field footway_headroom => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Will the headroom over any footway be less than 2m?',
    required => 1,
    tags => { hint => 'If yes, then a site meeting between the applicant and TfL may be required.' },
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
    tags => { hint => 'If yes, then a site meeting between the applicant and TfL may be required.' },
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
    tags => { hint => 'If yes, a site meeting between the applicant and TfL may be required.' },
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
    tags => { hint => 'If yes, a site meeting between the applicant and TfL may be required.' },
    required => 1,
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

has_field site_obstruct_infrastructure => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Will any banners obstruct or obscure any of the following: traffic signal, traffic signal controller, bus stop, pedestrian crossing, junction sight line, road lighting column, traffic sign, parking bay, or any ‘ironwork’ in the highway or other street furniture?',
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
