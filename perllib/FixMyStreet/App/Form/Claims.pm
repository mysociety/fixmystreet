package FixMyStreet::App::Form::Claims;

use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Wizard';
use utf8;
use Path::Tiny;

has default_page_type => ( is => 'ro', isa => 'Str', default => 'Wizard' );

has finished_action => ( is => 'ro' );

has '+is_html5' => ( default => 1 );

has upload_subdir => ( is => 'ro', default => 'claims_files' );

has_page intro => (
    fields => ['start'],
    title => 'Claim for Damages',
    intro => 'start.html',
    tags => { hide => 1 },
    next => 'what',
);

has_page what => (
    fields => ['what', 'claimed_before', 'continue'],
    title => 'What are you claiming for',
    next => 'about_you',
);

has_field what => (
    required => 1,
    type => 'Select',
    widget => 'RadioGroup',
    label => 'What are you claiming for?',
    options => [
        { value => 'vehicle', label => 'Vehicle damage' },
        { value => 'personal', label => 'Personal injury' },
        { value => 'property', label => 'Property' },
    ]
);

has_field claimed_before => (
    type => 'Select',
    widget => 'RadioGroup',
    required => 1,
    label => 'Have you ever filed a Claim for damages with Buckinghamshire Council?',
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

has_page about_you => (
    fields => ['name', 'phone', 'email', 'address', 'continue'],
    title => 'About you',
    next => 'fault_fixed',
);

has email_hint => ( is => 'ro', default => 'We’ll only use this to send you updates on your claim' );
has phone_hint => ( is => 'ro', default => 'We will call you on this number to discuss your claim' );

with 'FixMyStreet::App::Form::AboutYou';

has_field address => (
    required => 1,
    type => 'Text',
    widget => 'Textarea',
    label => 'Full address',
    tags => {
        hint => "Including postcode",
    },
);

has_page fault_fixed => (
    fields => ['fault_fixed', 'continue'],
    title => 'About the fault',
    next => sub {
        $_[0]->{fault_fixed} eq 'Yes' ? 'where' :
        'fault_reported'
    }
);

has_field fault_fixed => (
    type => 'Select',
    widget => 'RadioGroup',
    required => 1,
    label => 'Has the highways fault been fixed?',
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
        { label => 'Don’t know', value => 'Unknown' },
    ],
);

has_page fault_reported => (
    fields => [ 'fault_reported', 'continue' ],
    title => 'About the fault',
    intro => 'fault_reported.html',
    next => sub {
        $_[0]->{fault_reported} eq 'Yes' ? 'about_fault' :
        'submit_first'
    },
    tags => {
        hide => sub { $_[0]->form->value_equals('fault_fixed', 'Yes'); }
    },
);

has_field fault_reported => (
    type => 'Select',
    widget => 'RadioGroup',
    required => 1,
    label => 'Have you reported the fault to the Council?',
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

has_page submit_first => (
    fields => ['continue'],
    intro => 'submit_first.html',
    title => 'Please make a fault report',
    tags => {
        hide => sub { $_[0]->form->value_equals('fault_fixed', 'Yes'); }
    },
    next => 'fault_reported',
);

has_page about_fault => (
    fields => ['report_id', 'continue'],
    intro => 'fault_reported.html',
    title => 'About the fault',
    tags => {
        hide => sub { $_[0]->form->value_equals('fault_fixed', 'Yes'); }
    },
    next => 'where',
);

has_field report_id => (
    required => 1,
    type => 'Text',
    label => 'Fault ID',
    tags => { hint => 'This will have been sent to you in an email when you reported the fault' },
    validate_method => sub {
        my $self = shift;
        my $c = $self->form->c;
        return if $self->has_errors; # Called even if already failed
        unless ($self->value =~ /^[0-9]+$/) {
            $self->add_error('Please provide a valid report ID');
        }
    },
);

has_page where => (
    fields => ['location', 'continue'],
    title => 'Where did the incident happen',
    next => sub { $_[0]->{possible_location_matches} ? 'choose_location' : $_[0]->{latitude} ? 'map' : 'choose_location' },
);

has_field location => (
    required => 1,
    tags => {
        hint => 'If you know the postcode please use that',
    },
    type => 'Text',
    label => 'Postcode, or street name and area of the source',
    validate_method => sub {
        my $self = shift;
        my $c = $self->form->c;
        return if $self->has_errors; # Called even if already failed
        my $value = $self->value;
        my $saved_data  = $self->form->saved_data;
        my $ret = $c->forward('/location/determine_location_from_pc', [ $self->value ]);
        if (!$ret) {
            if ( $c->stash->{possible_location_matches} ) {
                return $saved_data->{possible_location_matches} = $c->stash->{possible_location_matches};
            } else {
                $self->add_error($c->stash->{location_error});
            }
        }
        $saved_data->{latitude} = $c->stash->{latitude};
        $saved_data->{longitude} = $c->stash->{longitude};
    },
);

has_page 'choose_location' => (
    fields => ['location_matches', 'continue'],
    title => 'The location of the incident',
    tags => { hide => 1 },
    next => 'map',
    update_field_list => sub {
        my $form = shift;
        my $saved_data = $form->saved_data;
        my $locations = $saved_data->{possible_location_matches};
        my $options = [];
        for my $location ( @$locations ) {
            push @$options, { label => $location->{address}, value => $location->{latitude} . "," . $location->{longitude} }
        }
        return { location_matches => { options => $options } };
    },
    post_process => sub {
        my $form = shift;
        my $saved_data = $form->saved_data;
        if ( my $location = $saved_data->{location_matches} ) {
            my ($lat, $lon) = split ',', $location;
            $saved_data->{latitude} ||= $lat;
            $saved_data->{longitude} ||= $lon;
        }
    },
);

has_field 'location_matches' => (
    required => 1,
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Select a location',
    tags => { hide => 1 },
    validate_method => sub {
        my $self = shift;
        my $value = $self->value;
        my $saved_data  = $self->form->saved_data;

        if ($saved_data->{location_matches} && $value ne $saved_data->{location_matches}) {
            delete $saved_data->{latitude};
            delete $saved_data->{longitude};
        }
    }
);

has_page map => (
    fields => ['latitude', 'longitude', 'continue'],
    title => 'The location of the incident',
    template => 'claims/map.html',
    next => 'when',
    update_field_list => sub {
        my $form = shift;
        my $c = $form->c;
        if ($c->forward('/report/new/determine_location_from_tile_click')) {
            $c->forward('/around/check_location_is_acceptable', []);
            # We do not want to process the form if they have clicked the map
            $c->stash->{override_no_process} = 1;

            my $saved_data = $form->saved_data;
            $saved_data->{latitude} = $c->stash->{latitude};
            $saved_data->{longitude} = $c->stash->{longitude};
            return {};
        }
    },
    post_process => sub {
        my $form = shift;
        my $c = $form->c;
        my $latitude = $form->fif->{latitude};
        my $longitude = $form->fif->{longitude};
        $c->stash->{page} = 'new';
        FixMyStreet::Map::display_map(
            $c,
            latitude => $latitude,
            longitude => $longitude,
            clickable => 1,
            pins => [ {
                latitude => $latitude,
                longitude => $longitude,
                draggable => 1,
                colour => $c->cobrand->pin_new_report_colour,
            } ],
        );
    },
);

has_field latitude => (
    label => 'Latitude',
    type => 'Hidden'
);

has_field longitude => (
    label => 'Longitude',
    type => 'Hidden'
);

has_page when => (
    fields => ['incident_date', 'incident_time', 'continue'],
    title => 'When did the incident happen',
    next => sub {
            $_[0]->{what} eq 'vehicle' ? 'details_vehicle' : $_[0]->{what} eq 'personal' ? 'details_personal' : 'details_property'
        },
);

has_field incident_date => (
    required => 1,
    type => 'DateTime',
    tags => { hint => 'For example 27 09 2020' },
    label => 'What day did the incident happen?',
    messages => {
        datetime_invalid => 'Please enter a valid date',
    },
    set_validate => 'validate_datetime',
);

has_field 'incident_date.year' => (
    type => 'Year',
    messages => {
        select_invalid_value => 'The incident must be within the last five years',
    },
);
has_field 'incident_date.month' => (
    type => 'Month',
    messages => {
        select_invalid_value => 'Please enter a month',
    },
);
has_field 'incident_date.day' => (
    type => 'MonthDay',
    messages => {
        select_invalid_value => 'Please enter a valid day of the month',
    },
);

has_field incident_time => (
    required => 1,
    type => 'Text',
    html5_type_attr => 'time',
    tags => { hint => 'For example 06:30 PM or 18:30 depending on your settings' },
    label => 'What time did the incident happen?',
);

has_page details_vehicle => (
    fields => ['weather', 'direction', 'details', 'in_vehicle', 'speed', 'actions', 'continue'],
    title => 'What are the details of the incident',
    next => 'witnesses',
    tags => {
        hide => sub { $_[0]->form->value_nequals('what', 'vehicle'); }
    },
);

has_page details_personal => (
    fields => ['weather', 'direction', 'details', 'continue'],
    title => 'What are the details of the incident',
    next => 'witnesses',
    tags => {
        hide => sub { $_[0]->form->value_nequals('what', 'personal'); }
    },
);

has_page details_property => (
    fields => ['weather', 'details', 'continue'],
    title => 'What are the details of the incident',
    next => 'witnesses',
    tags => {
        hide => sub { $_[0]->form->value_nequals('what', 'property'); }
    },
);

has_field weather => (
    required => 1,
    type => 'Text',
    label => 'Describe the weather conditions at the time',
);

has_field direction => (
    required_when => { 'what' => sub { $_[1]->form->saved_data->{what} ne 'property'; } },
    type => 'Text',
    label => 'What direction were you travelling in at the time?',
);

has_field details => (
    required => 1,
    type => 'Text',
    widget => 'Textarea',
    tags => { hint => 'Please provide as much information as possible, eg. direction of travel, reason for journey.' },
    label => 'Describe the details of the incident',
);

has_field in_vehicle => (
    type => 'Select',
    widget => 'RadioGroup',
    required_when => { 'what' => sub { $_[1]->form->saved_data->{what} eq 'vehicle'; } },
    label => 'Were you in a vehicle when the incident happened?',
    tags => {
        hide => sub { $_[0]->form->value_nequals('what', 'vehicle'); }
    },
    options => [
        { label => 'Yes', value => 'Yes', data_show => '#form-speed-row,#form-actions-row' },
        { label => 'No', value => 'No', data_hide => '#form-speed-row,#form-actions-row' },
    ],
);

has_field speed => (
    required_when => { 'in_vehicle' => 'Yes' },
    type => 'Text',
    tags => {
        hide => sub { $_[0]->form->value_nequals('what', 'vehicle'); }
    },
    label => 'What speed was the vehicle travelling?',
);

has_field actions => (
    type => 'Text',
    widget => 'Textarea',
    tags => {
        hide => sub { $_[0]->form->value_nequals('what', 'vehicle'); }
    },
    label => 'If you were not driving, what were you doing when the incident happened?',
);

has_page witnesses => (
    fields => ['witnesses', 'witness_details', 'report_police', 'incident_number', 'continue'],
    title => 'Witnesses and police',
    next => 'cause',
);

has_field witnesses => (
    type => 'Select',
    widget => 'RadioGroup',
    required => 1,
    label => 'Were there any witnesses?',
    options => [
        { label => 'Yes', value => 'Yes', data_show => '#form-witness_details-row' },
        { label => 'No', value => 'No', data_hide => '#form-witness_details-row'  },
    ],
);

has_field witness_details => (
    type => 'Text',
    widget => 'Textarea',
    tags => {
        hint => 'Please give their name, contact number, address and if they are related to you',
        hide => sub { $_[0]->form->value_equals('witnesses', 'No'); }
    },
    label => 'Please give the witness’ details',
);

has_field report_police => (
    type => 'Select',
    widget => 'RadioGroup',
    required => 1,
    label => 'Did you report the incident to the police?',
    options => [
        { label => 'Yes', value => 'Yes', data_show => '#form-incident_number-row' },
        { label => 'No', value => 'No', data_hide => '#form-incident_number-row' },
    ],
);

has_field incident_number => (
    type => 'Text',
    tags => {
        hide => sub { $_[0]->form->value_equals('report_police', 'No'); }
    },
    label => 'What was the incident reference number?',
);


has_page cause => (
    fields => ['what_cause', 'what_cause_other', 'aware', 'where_cause', 'describe_cause', 'photos_fileid', 'photos', 'continue'],
    title => 'What caused the incident?',
    next => sub {
            $_[0]->{what} eq 'vehicle' ? 'about_vehicle' :
            $_[0]->{what} eq 'personal' ? 'about_you_personal' :
            'about_property',
    },
);

has_field what_cause => (
    type => 'Select',
    widget => 'RadioGroup',
    required => 1,
    label => 'What was the cause of the incident?',
    options => [
        { label => 'Bollard', value => 'bollard', data_hide => '#form-what_cause_other-row' },
        { label => 'Cats Eyes', value => 'catseyes', data_hide => '#form-what_cause_other-row' },
        { label => 'Debris', value => 'debris', data_hide => '#form-what_cause_other-row' },
        { label => 'Drains/Manhole covers', value => 'drains', data_hide => '#form-what_cause_other-row' },
        { label => 'Edge Rut', value => 'edge_rut', data_hide => '#form-what_cause_other-row' },
        { label => 'Fall', value => 'fall', data_hide => '#form-what_cause_other-row' },
        { label => 'Flooding', value => 'flooding', data_hide => '#form-what_cause_other-row' },
        { label => 'Grass Cutting', value => 'grass_cutting', data_hide => '#form-what_cause_other-row' },
        { label => 'Gully/Grate', value => 'gully_grate', data_hide => '#form-what_cause_other-row' },
        { label => 'Ice/Snow', value => 'ice_snow', data_hide => '#form-what_cause_other-row' },
        { label => 'Kerbing', value => 'kerbing', data_hide => '#form-what_cause_other-row' },
        { label => 'Loose chippings', value => 'loose_chippings', data_hide => '#form-what_cause_other-row' },
        { label => 'Loose paving', value => 'loose_paving', data_hide => '#form-what_cause_other-row' },
        { label => 'Noise', value => 'noise', data_hide => '#form-what_cause_other-row' },
        { label => 'Pothole', value => 'pothole', data_hide => '#form-what_cause_other-row' },
        { label => 'Signage', value => 'signage', data_hide => '#form-what_cause_other-row' },
        { label => 'Street furniture', value => 'street_furniture', data_hide => '#form-what_cause_other-row' },
        { label => 'Strimmer/Ride on Mower', value => 'strimmer_mower', data_hide => '#form-what_cause_other-row' },
        { label => 'Tar Splashes', value => 'tar_splashes', data_hide => '#form-what_cause_other-row' },
        { label => 'Transport for Bucks Vehicle', value => 'tfb_vehicle', data_hide => '#form-what_cause_other-row' },
        { label => 'Traffic Calming', value => 'traffic_calming', data_hide => '#form-what_cause_other-row' },
        { label => 'Tree/Hedge', value => 'tree_hedge', data_hide => '#form-what_cause_other-row' },
        { label => 'Uneven Surface', value => 'uneven_surface', data_hide => '#form-what_cause_other-row' },
        { label => 'Utility Cover', value => 'utility_cover', data_hide => '#form-what_cause_other-row' },
        { label => 'Winter Gritting', value => 'winter_gritting', data_hide => '#form-what_cause_other-row' },
        { label => 'Other', value => 'other', data_show => '#form-what_cause_other-row' },
    ],
);

has_field what_cause_other => (
    type => 'Text',
    label => 'Other cause',
    required_when => { 'what_cause' => 'other' },
    tags => {
        hide => sub { $_[0]->form->value_nequals('what_cause', 'other') },
    },
);

has_field aware => (
    type => 'Select',
    widget => 'RadioGroup',
    required => 1,
    label => 'Were you aware of it before?',
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

has_field where_cause => (
    type => 'Select',
    widget => 'RadioGroup',
    required => 1,
    label => 'Where was the cause of the incident?',
    options => [
        { label => 'Bridge', value => 'bridge' },
        { label => 'Bridleway', value => 'bridleway' },
        { label => 'Car park', value => 'car_park' },
        { label => 'Cycleway', value => 'cycleway' },
        { label => 'Driveway', value => 'driveway' },
        { label => 'Footbridge', value => 'footbridge' },
        { label => 'Footpath/Pavement', value => 'footpath' },
        { label => 'Layby', value => 'layby' },
        { label => 'Rights of Way', value => 'rights_of_way' },
        { label => 'Road/Carriageway', value => 'carriageway' },
    ],
);

has_field describe_cause => (
    required => 1,
    type => 'Text',
    widget => 'Textarea',
    tags => { hint => 'Include measurements (width, length and depth) where possible' },
    label => 'Describe the incident cause',
);

has_field photos_fileid => (
    type => 'FileIdPhoto',
    num_photos_required => 0,
    linked_field => 'photos',
);

has_field photos => (
    type => 'Photo',
    tags => {
        max_photos => 2,
        hint => '(if safe to do so) including views that would help identify the location. We recommend a close up photo and a long shot showing the defect and the location.',
    },
    label => 'Please provide two dated photos of the incident',
);

has_page about_vehicle => (
    fields => ['registration', 'mileage', 'v5', 'v5_in_name', 'insurer_address', 'damage_claim', 'vat_reg', 'continue'],
    title => 'About the vehicle',
    tags => {
        hide => sub { $_[0]->form->value_nequals('what', 'vehicle'); }
    },
    next => 'damage_vehicle',
    update_field_list => sub {
        my ($form) = @_;
        my $fields = {};
        $form->handle_upload( 'v5', $fields );

        return $fields;
    },
    post_process => sub {
        my ($form) = @_;

        $form->process_upload('v5');
    },
);

has_field registration => (
    required => 1,
    type => 'Text',
    label => 'Registration number',
);

has_field mileage => (
    required => 1,
    type => 'Text',
    label => 'Vehicle mileage',
);

has_field v5 => (
    validate_when_empty => 1,
    type => 'FileIdUpload',
    label => 'Copy of the vehicle’s V5 Registration Document',
    tags => {
        hint => "If the vehicle is hired please upload a copy of the rental agreement",
    },
    messages => {
        upload_file_not_found => 'Please provide a copy of the V5 Registration Document',
    },
);

has_field v5_in_name => (
    type => 'Select',
    widget => 'RadioGroup',
    required => 1,
    label => 'Is the V5 document in your name?',
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

has_field insurer_address => (
    type => 'Text',
    widget => 'Textarea',
    label => 'Name and address of the Vehicle\'s Insurer',
);

has_field damage_claim => (
    type => 'Select',
    widget => 'RadioGroup',
    required => 1,
    label => 'Are you making a claim via the insurance company?',
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

has_field vat_reg => (
    type => 'Select',
    widget => 'RadioGroup',
    required => 1,
    label => 'Are you registered for VAT?',
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

has_page damage_vehicle => (
    fields => ['vehicle_damage', 'vehicle_photos_fileid', 'vehicle_photos', 'vehicle_receipts', 'tyre_damage', 'tyre_mileage', 'continue'],
    title => 'What was the damage to the vehicle',
    tags => {
        hide => sub { $_[0]->form->value_nequals('what', 'vehicle'); }
    },
    next => 'summary',
    update_field_list => sub {
        my ($form) = @_;
        my $fields = {};
        my $c = $form->{c};

        $form->handle_upload( 'vehicle_receipts', $fields );

        return $fields;
    },
    post_process => sub {
        my ($form) = @_;

        $form->process_upload('vehicle_receipts');
    },
);

has_field vehicle_damage => (
    required => 1,
    type => 'Text',
    widget => 'Textarea',
    label => 'Describe the damage to the vehicle',
);

has_field vehicle_photos_fileid => (
    type => 'FileIdPhoto',
    num_photos_required => 2,
    linked_field => 'vehicle_photos',
);

has_field vehicle_photos => (
    type => 'Photo',
    tags => { max_photos => 2 },
    label => 'Please provide two photos of the damage to the vehicle',
);

has_field vehicle_receipts => (
    validate_when_empty => 1,
    type => 'FileIdUpload',
    label => 'Please provide receipted invoices for repairs',
    tags => { hint => 'Or estimates where the damage has not yet been repaired' },
    messages => {
        upload_file_not_found => 'Please provide invoices for repairs',
    },
);

has_field tyre_damage => (
    type => 'Select',
    widget => 'RadioGroup',
    required => 1,
    label => 'Are you claiming for tyre damage?',
    options => [
        { label => 'Yes', value => 'Yes', data_show => '#form-tyre_mileage-row' },
        { label => 'No', value => 'No', data_hide => '#form-tyre_mileage-row' },
    ],
);

has_field tyre_mileage => (
    type => 'Integer',
    label => 'Mileage of the tyre(s) at the time of the incident',
    tags => {
        hide => sub { $_[0]->form->value_equals('tyre_damage', 'No') }
    },
    required_when => { 'tyre_damage' => 'Yes' },
);

has_page about_property => (
    fields => ['property_insurance', 'continue'],
    title => 'About the property',
    tags => {
        hide => sub { $_[0]->form->value_nequals('what', 'property'); }
    },
    next => 'damage_property',
    update_field_list => sub {
        my ($form) = @_;
        my $fields = {};
        $form->handle_upload( 'property_insurance', $fields );
        return $fields;
    },
    post_process => sub {
        my ($form) = @_;
        $form->process_upload('property_insurance');
    },
);

has_field property_insurance => (
    type => 'FileIdUpload',
    label => 'Please provide a copy of the home/contents insurance certificate',
    tags => {
        hint => 'Optional'
    },
    messages => {
        upload_file_not_found => 'Please provide a copy of the insurance certificate',
    },
);

has_page damage_property => (
    fields => ['property_damage_description', 'property_photos_fileid', 'property_photos', 'property_invoices', 'continue'],
    title => 'What was the damage to the property?',
    tags => {
        hide => sub { $_[0]->form->value_nequals('what', 'property'); }
    },
    next => 'summary',
    update_field_list => sub {
        my ($form) = @_;
        my $fields = {};
        $form->handle_upload( 'property_invoices', $fields );
        return $fields;
    },
    post_process => sub {
        my ($form) = @_;
        $form->process_upload( 'property_invoices');
    },
);

has_field property_damage_description => (
    required => 1,
    type => 'Text',
    widget => 'Textarea',
    label => 'Describe the damage to the property',
);

has_field property_photos_fileid => (
    type => 'FileIdPhoto',
    num_photos_required => 2,
    linked_field => 'property_photos',
);

has_field property_photos => (
    type => 'Photo',
    tags => { max_photos => 2 },
    label => 'Please provide two photos of the damage to the property',
);

has_field property_invoices => (
    type => 'FileIdUpload',
    validate_when_empty => 1,
    tags => { hint => 'Or estimates where the damage has not yet been repaired. These must be on headed paper, addressed to you and dated' },
    label => 'Please provide receipted invoices for repairs',
    messages => {
        upload_file_not_found => 'Please provide a copy of the repair invoices',
    },
);

has_page about_you_personal => (
    fields => ['dob', 'ni_number', 'occupation', 'employer_contact', 'continue'],
    title => 'About you',
    tags => {
        hide => sub { $_[0]->form->value_nequals('what', 'personal'); }
    },
    next => 'injuries',
);

has_field dob => (
    required => 1,
    type => 'DateTime',
    tags => { hint => 'For example 23 05 1983' },
    label => 'Your date of birth',
    messages => {
        datetime_invalid => 'Please enter a valid date',
    },
    set_validate => 'validate_datetime',
);

has_field 'dob.year' => (
    type => 'DOBYear',
    messages => {
        select_invalid_value => 'You must be over 16 to make a claim',
    },
);
has_field 'dob.month' => (
    type => 'Month',
    messages => {
        select_invalid_value => 'Please enter a month',
    },
);
has_field 'dob.day' => (
    type => 'MonthDay',
    messages => {
        select_invalid_value => 'Please enter a valid day of the month',
    },
);

has_field ni_number => (
    required => 1,
    type => 'Text',
    tags => { hint => "It's on your National Insurance card, benefit letter, payslip or P60. For example 'QQ 12 34 56 C'." },
    label => 'Your national insurance number',
);

has_field occupation => (
    required => 1,
    type => 'Text',
    label => 'Your occupation',
);

has_field employer_contact => (
    required => 1,
    type => 'Text',
    widget => 'Textarea',
    label => 'Your employer\'s contact details',
);

has_page injuries => (
    fields => ['describe_injuries', 'medical_attention', 'attention_date', 'gp_contact', 'absent_work', 'absence_dates', 'ongoing_treatment', 'treatment_details', 'continue'],
    title => 'About your injuries',
    tags => {
        hide => sub { $_[0]->form->value_nequals('what', 'personal'); }
    },
    next => 'summary',
);

has_field describe_injuries => (
    required => 1,
    type => 'Text',
    widget => 'Textarea',
    label => 'Describe the injuries you sustained',
);

has_field medical_attention => (
    type => 'Select',
    widget => 'RadioGroup',
    required => 1,
    label => 'Did you seek medical attention?',
    options => [
        { label => 'Yes', value => 'Yes', data_show => '#form-attention_date-row,#form-gp_contact-row' },
        { label => 'No', value => 'No', data_hide => '#form-attention_date-row,#form-gp_contact-row' },
    ],
);

has_field attention_date => (
    required => 0,
    type => 'DateTime',
    label => 'Date you received medical attention',
    required_when => { 'medical_attention' => 'Yes' },
    tags => {
        hint => 'For example 11 08 2020',
        hide => sub { $_[0]->form->value_equals('medical_attention', 'No'); }
    },
    messages => {
        select_invalid_value => 'The incident must be within the last five years',
    },
    set_validate => 'validate_datetime',
);

has_field 'attention_date.year' => (
    type => 'Year',
    messages => {
        select_invalid_value => 'The incident must be within the last five years',
    },
);
has_field 'attention_date.month' => (
    type => 'Month',
    messages => {
        select_invalid_value => 'Please enter a month',
    },
);
has_field 'attention_date.day' => (
    type => 'MonthDay',
    messages => {
        select_invalid_value => 'Please enter a valid day of the month',
    },
);

has_field gp_contact => (
    required => 0,
    type => 'Text',
    widget => 'Textarea',
    label => 'Please give the name and contact details of the GP or hospital where you received medical attention',
    required_when => { 'medical_attention' => 'Yes' },
    tags => {
        hide => sub { $_[0]->form->value_equals('medical_attention', 'No'); }
    },
);

has_field absent_work => (
    type => 'Select',
    widget => 'RadioGroup',
    required => 1,
    label => 'Were you absent from work due to the incident?',
    options => [
        { label => 'Yes', value => 'Yes', data_show => '#form-absence_dates-row' },
        { label => 'No', value => 'No', data_hide => '#form-absence_dates-row' },
    ],
);

has_field absence_dates => (
    required => 0,
    type => 'Text',
    widget => 'Textarea',
    label => 'Please give dates of absences',
    required_when => { 'absent_work' => 'Yes' },
    tags => {
        hide => sub { $_[0]->form->value_equals('absent_work', 'No'); }
    },
);

has_field ongoing_treatment => (
    type => 'Select',
    widget => 'RadioGroup',
    required => 1,
    label => 'Are you having any ongoing treatment?',
    options => [
        { label => 'Yes', value => 'Yes', data_show => '#form-treatment_details-row' },
        { label => 'No', value => 'No', data_hide => '#form-treatment_details-row' },
    ],
);

has_field treatment_details => (
    required => 0,
    type => 'Text',
    widget => 'Textarea',
    label => 'Please give treatment details',
    required_when => { 'ongoing_treatment' => 'Yes' },
    tags => {
        hide => sub { $_[0]->form->value_equals('ongoing_treatment', 'No'); }
    },
);


has_page summary => (
    fields => ['submit'],
    tags => { hide => 1 },
    title => 'Review',
    template => 'claims/summary.html',
    finished => sub {
        my $form = shift;
        my $c = $form->c;
        my $success = $c->forward('process_claim', [ $form ]);
        if (!$success) {
            $form->add_form_error('Something went wrong, please try again');
            foreach (keys %{$c->stash->{field_errors}}) {
                $form->add_form_error("$_: " . $c->stash->{field_errors}{$_});
            }
        }
        return $success;
    },
    next => 'done',
);

has_page done => (
    tags => { hide => 1 },
    title => 'Submit',
    template => 'claims/confirmation.html',
);

has_field start => ( type => 'Submit', value => 'Start', element_attr => { class => 'govuk-button' } );
has_field continue => ( type => 'Submit', value => 'Continue', element_attr => { class => 'govuk-button' } );
has_field submit => ( type => 'Submit', value => 'Submit', element_attr => { class => 'govuk-button' } );

sub value_equals {
    my ($form, $field, $answer) = @_;

    return defined $form->saved_data->{$field} &&
        $form->saved_data->{$field} eq $answer;
}

sub value_nequals {
    my ($form, $field, $answer) = @_;

    return defined $form->saved_data->{$field} &&
        $form->saved_data->{$field} ne $answer;
}

# this makes sure that if any of the child fields have errors we mark the date
# as invalid, even if it's technically a valid date. This is mostly to catch
# range errors on the year. Otherwise we get an error at the top of the page
# but the field isn't highlighted
sub validate_datetime {
    my ($form, $field) = @_;

    if ($field->value > DateTime->today(time_zone => FixMyStreet->local_time_zone)) {
        $field->add_error("You cannot enter a date in the future");
    }

    return if scalar @{ $field->errors };
    my $valid = 1;
    for my $child ( @{ $field->{fields} } ) {
        $valid = 0 if scalar @{ $child->errors };
    }

    $field->add_error("Please enter a valid date") unless $valid;
}

1;
