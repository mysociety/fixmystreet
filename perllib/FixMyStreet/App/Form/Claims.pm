package FixMyStreet::App::Form::Claims;

use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Wizard';
use utf8;

has c => ( is => 'ro' );

has default_page_type => ( is => 'ro', isa => 'Str', default => 'Wizard' );

has finished_action => ( is => 'ro' );

before _process_page_array => sub {
    my ($self, $pages) = @_;
    foreach my $page (@$pages) {
        $page->{type} = $self->default_page_type
            unless $page->{type};
    }
};

# Add some functions to the form to pass through to the current page
has '+current_page' => (
    handles => {
        intro_template => 'intro',
        title => 'title',
        template => 'template',
    }
);

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
        { value => '0', label => 'Vehicle damage' },
        { value => '1', label => 'Personal injury' },
        { value => '2', label => 'Property' },
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
    label => 'Address',
);

has_page fault_fixed => (
    fields => ['fault_fixed', 'continue'],
    intro => 'fault_fixed.html',
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
    label => 'Has the fault been fixed?',
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
        'where'
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


has_page about_fault => (
    fields => ['report_id', 'continue'],
    intro => 'fault_reported.html',
    title => 'About the fault',
    next => 'where',
    tags => {
        hide => sub { $_[0]->form->value_equals('fault_fixed', 'Yes'); }
    },
);

has_field report_id => (
    required => 1,
    type => 'Text',
    label => 'Fault ID',
);

has_page where => (
    fields => ['location', 'continue'],
    title => 'Where did the incident happen',
    next => 'when',
);

has_field location => (
    required => 1,
    type => 'Text',
    widget => 'Textarea',
    label => 'Place a pin on the map (TBD)',
);

has_page when => (
    fields => ['incident_date', 'incident_time', 'continue'],
    title => 'When did the incident happen',
    next => sub {
            $_[0]->{what} == 0 ? 'details_vehicle' : 'details_no_vehicle'
        },
);

has_field incident_date => (
    required => 1,
    type => 'DateTime',
    hint => 'For example 27 09 2020',
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
    label => 'What time did the incident happen?',
);

has_page details_vehicle => (
    fields => ['weather', 'direction', 'details', 'in_vehicle', 'speed', 'actions', 'continue'],
    title => 'What are the details of the incident',
    next => 'witnesses',
);

has_page details_no_vehicle => (
    fields => ['weather', 'direction', 'details', 'continue'],
    title => 'What are the details of the incident',
    next => 'witnesses',
);

has_field weather => (
    required => 1,
    type => 'Text',
    label => 'Describe the weather conditions at the time',
);

has_field direction => (
    required_when => { 'what' => sub { $_[1]->form->saved_data->{what} == 0; } },
    type => 'Text',
    tags => {
        hide => sub { $_[0]->form->value_nequals('what', 0); }
    },
    label => 'What direction were you travelling in at the time?',
);

has_field details => (
    required => 1,
    type => 'Text',
    widget => 'Textarea',
    label => 'Describe the details of the incident',
);

has_field in_vehicle => (
    type => 'Select',
    widget => 'RadioGroup',
    required_when => { 'what' => sub { $_[1]->form->saved_data->{what} == 0; } },
    label => 'Were you in a vehicle when the incident happened?',
    tags => {
        hide => sub { $_[0]->form->value_nequals('what', 0); }
    },
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

has_field speed => (
    required_when => { 'what' => sub { $_[1]->form->saved_data->{what} == 0; } },
    type => 'Text',
    tags => {
        hide => sub { $_[0]->form->value_nequals('what', 0); }
    },
    label => 'What speed was the vehicle travelling?',
);

has_field actions => (
    required_when => { 'what' => sub { $_[1]->form->saved_data->{what} == 0; } },
    type => 'Text',
    widget => 'Textarea',
    tags => {
        hide => sub { $_[0]->form->value_nequals('what', 0); }
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
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

has_field witness_details => (
    type => 'Text',
    widget => 'Textarea',
    tags => {
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
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
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
    fields => ['what_cause', 'aware', 'where_cause', 'describe_cause', 'photos', 'continue'],
    title => 'What caused the incident?',
    next => sub {
            $_[0]->{what} == 0 ? 'about_vehicle' :
            $_[0]->{what} == 1 ? 'about_you_personal' :
            'about_property',
        },
);

has_field what_cause => (
    type => 'Select',
    widget => 'RadioGroup',
    required => 1,
    label => 'What was the cause of the incident?',
    options => [
        { label => 'Bollard', value => 'bollard' },
        { label => 'Cats Eyes', value => 'catseyes' },
        { label => 'Debris', value => 'debris' },
    ],
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
        { label => 'Carriageway', value => 'carriageway' },
    ],
);

has_field describe_cause => (
    required => 1,
    type => 'Text',
    widget => 'Textarea',
    label => 'Describe the incident cause',
);

has_field photos => (
    type => 'Text',
    label => 'Please provide two dated photos of the incident',
);

has_page about_vehicle => (
    fields => ['make', 'registration', 'mileage', 'v5', 'v5_in_name', 'insurer_address', 'damage_claim', 'vat_reg', 'continue'],
    title => 'About the vehicle',
    tags => {
        hide => sub { $_[0]->form->value_nequals('what', 0); }
    },
    next => 'damage_vehicle',
);

has_field make => (
    required => 1,
    type => 'Text',
    label => 'Make and model',
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
    required => 1,
    type => 'Text',
    label => 'Copy of the vehicle’s V5 Registration Document',
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
    fields => ['vehicle_damage', 'vehicle_photos', 'vehicle_receipts', 'tyre_damage', 'tyre_mileage', 'tyre_receipts', 'continue'],
    title => 'What was the damage to the vehicle',
    tags => {
        hide => sub { $_[0]->form->value_nequals('what', 0); }
    },
    next => 'summary',
);

has_field vehicle_damage => (
    required => 1,
    type => 'Text',
    widget => 'Textarea',
    label => 'Describe the damage to the vehicle',
);

has_field vehicle_photos => (
    required => 1,
    type => 'Text',
    label => 'Please provide two photos of the damage to the vehicle',
);

has_field vehicle_receipts=> (
    required => 1,
    type => 'Text',
    label => 'Please provide receipted invoiced for repairs',
    hint => 'Or estimates where the damage has not yet been repaired',
);

has_field tyre_damage => (
    type => 'Select',
    widget => 'RadioGroup',
    required => 1,
    label => 'Are you claiming for tyre damage?',
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

has_field tyre_mileage => (
    type => 'Text',
    label => 'Age and Mileage of the tyre(s) at the time of the incident',
    tags => {
        hide => sub { $_[0]->form->value_equals('tyre_damage', 'No') }
    },
    required_when => { 'tyre_damage' => 'Yes' },
);

has_field tyre_receipts => (
    type => 'Text',
    label => 'Please provide copy of tyre purchase receipts',
    tags => {
        hide => sub { $_[0]->form->value_equals('tyre_damage}', 'No') }
    },
    required_when => { 'tyre_damage' => 'Yes' },
);

has_field tyre_receipts => (
    type => 'Text',
    label => 'Please provide copy of tyre purchase receipts',
);

has_page about_property => (
    fields => ['property_insurance', 'continue'],
    title => 'About the property',
    tags => {
        hide => sub { $_[0]->form->value_nequals('what', 2); }
    },
    next => 'damage_property',
);

has_field property_insurance => (
    required => 1,
    type => 'Text',
    label => 'Please provide a copy of the home/contents insurance certificate',
);

has_page damage_property => (
    fields => ['property_damage_description', 'property_photos', 'property_invoices', 'continue'],
    title => 'What was the damage to the property?',
    tags => {
        hide => sub { $_[0]->form->value_nequals('what', 2); }
    },
    next => 'summary',
);

has_field property_damage_description => (
    required => 1,
    type => 'Text',
    widget => 'Textarea',
    label => 'Describe the damage to the property',
);

has_field property_photos => (
    required => 1,
    type => 'Text',
    label => 'Please provide two photos of the damage to the property',
);

has_field property_invoices => (
    required => 1,
    type => 'Text',
    hint => 'Or estimates where the damage has not yet been repaired. These must be on headed paper, addressed to you and dated',
    label => 'Please provide receipted invoices for repairs',
);

has_page about_you_personal => (
    fields => ['dob', 'ni_number', 'occupation', 'employer_contact', 'continue'],
    title => 'About you',
    tags => {
        hide => sub { $_[0]->form->value_nequals('what', 1); }
    },
    next => 'injuries',
);

has_field dob => (
    required => 1,
    type => 'DateTime',
    hint => 'For example 23 05 1983',
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
    hint => "It's on your National Insurance card, benefit letter, payslip or P60. For example 'QQ 12 34 56 C'.",
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
        hide => sub { $_[0]->form->value_nequals('what', 1); }
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
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

has_field attention_date => (
    required => 0,
    type => 'DateTime',
    hint => 'For example 11 08 2020',
    label => 'Date you received medical attention',
    required_when => { 'medical_attention' => 'Yes' },
    tags => {
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
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
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
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
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

sub fields_for_display {
    my ($form) = @_;

     my $things = [];
     for my $page ( @{ $form->pages } ) {
         my $x = {
             stage => $page->{name},
             title => $page->{title},
             ( $page->tag_exists('hide') ? ( hide => $page->get_tag('hide') ) : () ),
             fields => []
         };

         for my $f ( @{ $page->fields } ) {
             my $field = $form->field($f);
             next if $field->type eq 'Submit';
             my $value = $form->saved_data->{$field->{name}};
             push @{$x->{fields}}, {
                 name => $field->{name},
                 desc => $field->{label},
                 type => $field->type,
                 pretty => $form->format_for_display( $field->{name}, $value ),
                 value => $value,
                 ( $field->tag_exists('block') ? ( block => $field->get_tag('block') ) : () ),
                 ( $field->tag_exists('hide') ? ( hide => $field->get_tag('hide') ) : () ),
             };
         }

         push @$things, $x;
     }

     return $things;
}

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

sub label_for_field {
    my ($form, $field, $key) = @_;
    return "" unless $key;
    foreach ($form->field($field)->options) {
        return $_->{label} if $_->{value} eq $key;
    }
}

sub format_for_display {
    my ($form, $field_name, $value) = @_;
    my $field = $form->field($field_name);
    if ( $field->{type} eq 'Select' ) {
        return $form->label_for_field($field_name, $value);
    } elsif ( $field->{type} eq 'DateTime' ) {
        # if field was on the last screen then we get the DateTime and not
        # the hash because it's not been through the freeze/that process
        if ( ref $value eq 'DateTime' ) {
            return join( '/', $value->day, $value->month, $value->year);
        } else {
            return "" unless $value;
            return "$value->{day}/$value->{month}/$value->{year}";
        }
    }

    return $value;
}

# this makes sure that if any of the child fields have errors we mark the date
# as invalid, even if it's technically a valid date. This is mostly to catch
# range errors on the year. Otherwise we get an error at the top of the page
# but the field isn't highlighted
sub validate_datetime {
    my ($form, $field) = @_;

    return if scalar @{ $field->errors };
    my $valid = 1;
    for my $child ( @{ $field->{fields} } ) {
        $valid = 0 if scalar @{ $child->errors };
    }

    $field->add_error("Please enter a valid date") unless $valid;
}

1;
