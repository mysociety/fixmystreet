package FixMyStreet::App::Form::Licence::ColumnAttachments;

use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Licence::Base';
use utf8;

with 'FixMyStreet::App::Form::Licence::Fields::Electrical';

# Type identifier used in URL: /licence/column-attachments
sub type { 'column-attachments' }

# Human-readable name for display
sub name { 'Column Attachments' }

sub tandc_link { 'https://content.tfl.gov.uk/column-attachments-guidance-notes-and-terms-conditions.pdf' }

sub next_after_contractor { 'activity' }

sub num_steps { 14 }

# ==========================================================================
# Introduction / Before you get started
# ==========================================================================
has_page intro => (
    fields => ['start'],
    title => 'Column Attachments licence application',
    intro => 'column-attachments/intro.html',
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
    step_number => 1,
    fields => ['building_name_number', 'street_name', 'borough', 'postcode', 'add_another', 'continue'],
    title => 'Location of the Column Attachments',
    intro => 'location.html',
    next => sub { $_[1]->{add_another} ? 'location_2' : 'dates' },
    post_process => sub {
        my $form = shift;
        $form->post_process_location;
    },
);

foreach my $page (2..5) {
    my $next = 'dates';
    my $fields = ["building_name_number_$page", "street_name_$page", "borough_$page", "postcode_$page", 'continue'];
    if ($page < 5) {
        $next = sub { $_[1]->{add_another} ? 'location_' . ($page+1) : 'dates' };
        push @$fields, 'add_another';
    }
    has_page "location_$page" => (
        step_number => 1,
        fields => $fields,
        update_field_list => sub {
            my $data = $_[0]->saved_data;
            return {
                "street_name_$page" => { default => $data->{street_name} },
                "borough_$page" => { default => $data->{borough} },
            }
        },
        title => "Location of the Column Attachments ($page)",
        intro => 'column-attachments/location.html',
        next => $next,
        tags => { hide => sub { !$_[0]->form->saved_data->{"building_name_number_$page"} } },
    );
    has_field "building_name_number_$page" => ( type => 'Text', label => 'Building name / number', required => 1 );
    has_field "street_name_$page" => ( type => 'Text', label => 'Street name', disabled => 1 );
    has_field "borough_$page" => ( type => 'Text', label => 'Borough', disabled => 1 );
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
# Column Attachments activity
# ==========================================================================
has_page activity => (
    step_number => 5,
    fields => ['activity', 'continue'],
    title => 'Purpose of the column attachments',
    next => 'installation',
);

has_field activity => (
    type => 'Text',
    widget => 'Textarea',
    label => 'What activity will the licence be used for?',
    required => 1,
    tags => {
        hint => 'For example, ‘sensor attached to lamp columns for temporary traffic monitoring’',
    },
);

has_page installation => (
    step_number => 6,
    fields => ['installation_method', 'continue'],
    title => 'Installation',
    next => 'site_pedestrian_space',
);

has_field installation_method => (
    type => 'Text',
    widget => 'Textarea',
    label => 'How will the column attachment be installed?',
    required => 1,
    tags => {
        hint => 'For example, ‘mobile elevating work platform’ or ‘cherry picker’. Note a separate mobile apparatus application may also required',
    },
);

# ==========================================================================
# Site Specific Information (column-specific questions)
# Split into one question per page sometimes for better UX with long labels
# ==========================================================================
has_page site_pedestrian_space => (
    step_number => 7,
    fields => ['site_adequate_space', 'footway_incursion', 'footway_headroom', 'continue'],
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
    widget => 'Textarea',
    label => 'What is the proposed footway incursion?',
    required => 1,
    tags => {
        hint => 'For example, ‘1m from building line and 3m unobstructed footway’ or ‘no footway incursion’',
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
    step_number => 8,
    fields => ['carriageway_incursion', 'carriageway_headroom', 'continue'],
    title => 'Carriageway impact',
    next => 'site_infrastructure',
);

has_field carriageway_incursion => (
    type => 'Text',
    widget => 'Textarea',
    label => 'What is the proposed carriageway incursion?',
    required => 1,
    tags => {
        hint => 'For example, ‘No carriageway incursion’ or ‘temporary mobile lane closure for installation’',
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

has_page 'site_infrastructure' => (
    step_number => 9,
    fields => ['site_near_junction', 'site_obstruct_infrastructure', 'enough_space', 'power_supply', 'mpan_number', 'electrical_information', 'continue'],
    title => 'Street infrastructure',
    next => 'have_you_considered',
);

has_field site_near_junction => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Will any attachments be within 20m of a junction or a pedestrian crossing point?',
    required => 1,
    order => -2,
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

has_field site_obstruct_infrastructure => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Will any attachments obstruct or obscure any street furniture, such as traffic signals, crossings, or signs?',
    tags => { hint => 'Other examples (not limited to) include bus stops, traffic signal controllers, lighting columns, parking bays, and ironwork.' },
    required => 1,
    order => -1,
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
    step_number => 10,
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
    intro => 'column-attachments/have_you_considered.html',
    next => 'terms',
);

has_page terms => (
    step_number => 11,
    fields => [
        'terms_accepted',
        'continue'
    ],
    title => 'Terms and conditions confirmation',
    next => 'uploads',
);

# ==========================================================================
# Upload required documents (column-specific)
# ==========================================================================
my $upload_fields = [
    'upload_insurance',
    'insurance_validity',
    'upload_rams',
    'upload_map',
    'upload_structural_testing',
    'upload_additional',
    'continue'
];
has_page uploads => (
    step_number => 12,
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
    label => 'Map showing the location of each of the column attachments',
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

has_field upload_additional => (
    type => 'FileIdUpload',
    label => 'Additional supporting documentation',
    messages => {
        upload_file_not_found => 'Please upload any additional supporting documentation',
    },
);

__PACKAGE__->meta->make_immutable;

1;
