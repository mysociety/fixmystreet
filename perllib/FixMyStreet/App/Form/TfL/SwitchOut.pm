package FixMyStreet::App::Form::TfL::SwitchOut;

use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Wizard';
use utf8;
use Path::Tiny;

has default_page_type => ( is => 'ro', isa => 'Str', default => 'Wizard' );

has finished_action => ( is => 'ro' );

has '+is_html5' => ( default => 1 );

has upload_subdir => ( is => 'ro', default => 'tfl-switchout' );

has_page intro => (
    fields => ['start'],
    title => 'Traffic Signal Switch Out application',
    intro => 'intro.html',
    tags => { hide => 1 },
    next => 'where',
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
    title => 'Choose location',
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
    fields => ['asset_location', 'asset_borough', 'asset_site_id', 'latitude', 'longitude', 'continue'],
    title => 'Select traffic signal location you would like to switch out',
    template => 'switchout/map.html',
    next => 'emergency',
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

has_field asset_location => (
    required => 1,
    label => 'Location',
    type => 'Text',
);

has_field asset_borough => (
    required => 1,
    label => 'Borough',
    type => 'Text',
);

has_field asset_site_id => (
    required => 1,
    label => 'Site ID',
    type => 'Text',
);

has_field latitude => (
    label => 'Latitude',
    type => 'Hidden'
);

has_field longitude => (
    label => 'Longitude',
    type => 'Hidden'
);

has_page emergency => (
    fields => ['emergency', 'continue'],
    title => 'Proposed switch out date',
    next => sub { $_[0]->{emergency} eq 'Yes' ? 'call_us' : 'when_1' },
);

has_field emergency => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Is there a potential threat to life or property?',
    required => 1,
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

has_page call_us => (
    title => 'Emergency',
    intro => 'call_us.html',
);

sub when_page_fields {
    my $args = shift;
    my $page = $args->{page};
    my $next = 'dates';
    my $fields = ["switch_out_date_$page", "switch_out_time_$page", "restore_date_$page", "restore_time_$page", "switch_out_date_notice_$page", 'continue'];
    if ($page < $args->{pages}) {
        $next = sub { $_[1]->{add_another} ? 'when_' . ($page+1) : 'on_site' };
        push @$fields, 'add_another';
    }

    return (
        fields => $fields,
        title => "$args->{title} ($page)",
        intro => $args->{template},
        next => $next,
        tags => { hide => sub { !$_[0]->form->saved_data->{"switch_out_date_$page"} } },
    );
}

my @time_options = ({ label => "-", value => "" });
for my $h (0..23) {
    for my $m (0, 30) {
        next if !$h && !$m;
        my $time = sprintf("%02d:%02d", $h, $m);
        push @time_options, { label => $time, value => $time };
    }
}

for my $page (1..20) {
    has_page "when_$page" => when_page_fields({
        page => $page,
        pages => 20,
        title => 'Proposed switch out date',
        template => 'date.html',
    });
    has_field "switch_out_date_$page" => (
        required => 1, type => 'DateTime', label => 'Proposed switch out date', set_validate => 'validate_datetime',
        messages => { datetime_invalid => 'Please enter a valid date', },
    );
    has_field "switch_out_date_$page.year" => ( type => 'Year' );
    has_field "switch_out_date_$page.month" => ( type => 'Month' );
    has_field "switch_out_date_$page.day" => ( type => 'MonthDay' );
    has_field "switch_out_time_$page" => (
        type => 'Select',
        label => 'Proposed switch out time',
        required => 1,
        options => \@time_options,
    );
    has_field "restore_date_$page" => (
        required => 1, type => 'DateTime', label => 'Proposed restore date', set_validate => 'validate_datetime',
        messages => { datetime_invalid => 'Please enter a valid date', },
    );
    has_field "restore_date_$page.year" => ( type => 'Year' );
    has_field "restore_date_$page.month" => ( type => 'Month' );
    has_field "restore_date_$page.day" => ( type => 'MonthDay' );
    has_field "restore_time_$page" => (
        type => 'Select',
        label => 'Proposed restore time',
        required => 1,
        options => \@time_options,
    );
    has_field "switch_out_date_notice_$page" => (
        type => 'Notice',
        label => 'Do you require additional switch out and restore attendances at this location?',
        required => 0,
        widget => 'NoRender',
    );
}

has_field 'add_another' => (
    type => 'Submit',
    value => 'Add another',
    element_attr => {
        class => 'govuk-button govuk-button--secondary',
    },
);

has_page on_site => (
    fields => ['temporary_signal_company_name', 'temporary_signal_phone', 'site_contact_name', 'site_phone', 'continue'],
    title => 'Contacts for works on site',
    intro => 'on-site.html',
    next => 'applicant',
);

has_field temporary_signal_company_name => (
    type => 'Text',
    label => 'Temporary signal company name',
    required => 1,
);

has_field temporary_signal_phone => (
    type => 'Text',
    label => 'Temporary signal 24hr contact number',
    required => 1,
    validate_method => sub {
        my $self = shift;
        my $parsed = FixMyStreet::SMS->parse_username($self->value);
        $self->add_error('Please provide a valid phone number')
            unless $parsed->{phone};
    }
);

has_field site_contact_name => (
    type => 'Text',
    label => 'Site contact name',
    required => 1,
);

has_field site_phone => (
    type => 'Text',
    label => 'Site contact number',
    required => 1,
    validate_method => sub {
        my $self = shift;
        my $parsed = FixMyStreet::SMS->parse_username($self->value);
        $self->add_error('Please provide a valid phone number')
            unless $parsed->{phone};
    }
);

has_page applicant => (
    fields => ['organisation', 'name', 'email', 'phone', 'applicant_note', 'continue'],
    title => 'Applicant details',
    intro => 'applicant.html',
    next => 'lead',
);

has_field organisation => (
    type => 'Text',
    label => 'Your company name',
    required => 1,
);

has_field name => (
    type => 'Text',
    label => 'Applicant full name',
    required => 1,
);

has_field email => (
    required => 1,
    type => 'Email',
    label => 'Email address',
);

has_field phone => (
    required => 1,
    type => 'Text',
    label => 'Telephone number',
    validate_method => sub {
        my $self = shift;
        my $parsed = FixMyStreet::SMS->parse_username($self->value);
        $self->add_error('Please provide a valid phone number')
            unless $parsed->{phone};
    }
);

has_field applicant_note => (
    type => 'Notice',
    label =>
        'Please note that all correspondence relating to this application will be sent to the contact details provided above.',
    required => 0,
    widget => 'NoRender',
);

has_page lead => (
    fields => ['lead_same_as_applicant', 'lead_organisation', 'lead_contact_name', 'lead_email', 'lead_phone', 'continue'],
    title => 'Lead company details',
    intro => 'lead.html',
    next => 'permit',
);

has_field lead_same_as_applicant => (
    type => 'Checkbox',
    label => 'Same as applicant details',
    tags => {
        hint => 'Check this box if the lead company details are the same as the applicant',
    },
    option_label => 'Same as applicant',
);

has_field lead_organisation => (
    type => 'Text',
    label => 'Lead company name',
    required_when => { 'lead_same_as_applicant' => sub { !$_[0] } },
    tags => { hide => sub { $_[0]->form->saved_data->{lead_same_as_applicant} } },
);

has_field lead_contact_name => (
    type => 'Text',
    label => 'Contact name',
    required_when => { 'lead_same_as_applicant' => sub { !$_[0] } },
    tags => { hide => sub { $_[0]->form->saved_data->{lead_same_as_applicant} } },
);

has_field lead_email => (
    type => 'Email',
    label => 'Contact email',
    required_when => { 'lead_same_as_applicant' => sub { !$_[0] } },
    tags => { hide => sub { $_[0]->form->saved_data->{lead_same_as_applicant} } },
);

has_field lead_phone => (
    type => 'Text',
    label => 'Contact telephone number',
    required_when => { 'lead_same_as_applicant' => sub { !$_[0] } },
    tags => { hide => sub { $_[0]->form->saved_data->{lead_same_as_applicant} } },
    validate_method => sub {
        my $self = shift;
        my $parsed = FixMyStreet::SMS->parse_username($self->value);
        $self->add_error('Please provide a valid phone number')
            unless $parsed->{phone};
    }
);

has_page permit => (
    fields => ['permit_ha', 'permit_contact', 'permit_number', 'permit_nature', 'continue'],
    title => 'Permit details',
    intro => 'permit.html',
    next => 'uploads',
);

has_field permit_ha => (
    type => 'Text',
    label => 'Approving Highway Authority',
    required => 1,
);

has_field permit_contact => (
    type => 'Text',
    label => 'Highway Authority contact details',
    required => 1,
);

has_field permit_number => (
    type => 'Text',
    label => 'Permit number',
    tags => {
        hint => 'If works fall under an Emergency permit, state the word emergency in the text box',
    },
    required => 1,
);

has_field permit_nature => (
    type => 'Text',
    label => 'Nature of works',
    required => 1,
);

my $upload_fields = ['upload_document_1', 'upload_document_2', 'upload_document_3',
    'upload_missing_explanation', 'additional_information',
    'continue'];

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

has_field upload_document_1 => (
    required => 1,
    type => 'FileIdUpload',
    label => 'Traffic Management Drawing, Stage Diagram and Temporary Signal Timings Documents',
);

has_field upload_document_2 => (
    type => 'FileIdUpload',
    label => 'Traffic Management Drawing, Stage Diagram and Temporary Signal Timings Documents',
);

has_field upload_document_3 => (
    type => 'FileIdUpload',
    label => 'Traffic Management Drawing, Stage Diagram and Temporary Signal Timings Documents',
);

has_field upload_missing_explanation => (
    type => 'Text',
    widget => 'Textarea',
    label => 'If any of the requested information is unavailable, please provide details below. Our team will review the information provided and advise whether your application can proceed.',
);

has_field additional_information => (
    type => 'Text',
    widget => 'Textarea',
    label => 'Please provide any additional information relevant to this application that TfL or our contractors may need when reviewing your request or attending the site.',
    required => 1,
);

has_page payment => (
    fields => ['payment', 'continue'],
    title => 'Payment',
    next => sub { $_[0]->{payment} eq 'Invoice' ? 'payment_invoice' : 'payment_bacs' },
);

has_field payment => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'How would you like to pay?',
    required => 1,
    options => [
        { label => 'Invoice', value => 'Invoice' },
        { label => 'BACS', value => 'BACS' },
    ],
);

has_page payment_bacs => (
    title => 'BACS details',
    fields => ['payment_swo_ref', 'payment_bank_account', 'payment_bacs_naming_convention', 'payment_behalf', 'continue'],
    intro => 'bacs.html',
    next => 'terms',
    tags => { hide => sub { return $_[0]->form->saved_data->{payment} ne 'BACS' } },
);

has_field payment_swo_ref => (
    type => 'Text',
    label => 'Customer unique SWO ref',
    required => 1,
);
has_field payment_bank_account => (
    type => 'Text',
    label => 'Customer bank account number',
    required => 1,
);
has_field payment_bacs_naming_convention => (
    type => 'Text',
    label => 'BACS naming convention',
    required => 1,
);

has_page payment_invoice => (
    title => 'Payment details',
    fields => ['payment_company', 'payment_name', 'payment_email', 'payment_phone', 'payment_po', 'payment_behalf', 'continue'],
    intro => 'invoice.html',
    next => 'terms',
    tags => { hide => sub { return $_[0]->form->saved_data->{payment} ne 'Invoice' } },
);

has_field payment_company => (
    type => 'Text',
    label => 'Company paying invoice',
    required => 1,
);

has_field payment_name => (
    type => 'Text',
    label => 'Contact name',
    required => 1,
);

has_field payment_email => (
    required => 1,
    type => 'Email',
    label => 'Contact email address',
);

has_field payment_phone => (
    required => 1,
    type => 'Text',
    label => 'Contact telephone number',
    validate_method => sub {
        my $self = shift;
        my $parsed = FixMyStreet::SMS->parse_username($self->value);
        $self->add_error('Please provide a valid phone number')
            unless $parsed->{phone};
    }
);

has_field payment_po => (
    required => 1,
    type => 'Text',
    label => 'Purchase Oder Number',
);

has_field payment_behalf => (
    type => 'Text',
    label => 'If your works are on behalf of TfL or a London Borough, please state below',
);

has_page terms => (
    fields => ['terms_accepted', 'continue'],
    title => 'Terms and conditions confirmation',
    next => 'summary',
);

has_field terms_accepted => (
    type => 'Multiple',
    widget => 'CheckboxGroup',
    label => 'I confirm that I have read, understood, and agree to comply with all requirements contained within the following documents',
    required => 1,
    validate_method => sub {
        my $self = shift;
        my $vals = $self->value;
        $self->add_error('Please confirm all options') if @$vals < 2;
    },
);

sub options_terms_accepted {
    my @urls = (
        '',
        '',
    );
    my @labels = (
        'TfL Traffic Signal Switch out terms & conditions',
        'TfL Traffic Signal Switch out fee structure',
    );
    for (0..@labels-1) {
        $labels[$_] = {
            label => FixMyStreet::Template::SafeString->new("<a target='_blank' href='$urls[$_]'>$labels[$_]</a>"),
            value => $labels[$_],
        };
    }
    return @labels;
}

has_page summary => (
    fields => ['confirmation', 'submit'],
    title => 'Application summary',
    template => 'switchout/summary.html',
    finished => sub {
        my $form = shift;
        my $c = $form->c;
        my $success = $c->forward('process_switchout', [ $form ]);
        if (!$success) {
            $form->add_form_error('Something went wrong, please try again');
        }
        return $success;
    },
    next => 'done',
);

has_field confirmation => (
    type => 'Checkbox',
    label => '',
    required => 1,
    build_option_label_method => sub {
        my $name = $_[0]->form->saved_data->{name};
        "I, $name, confirm that the information I have provided in this application is true, complete and accurate to the best of my knowledge. I understand that providing false or misleading information may result in this application being refused.",
    }
);

has_field submit => (
    type => 'Submit',
    value => 'Submit application',
    element_attr => { class => 'govuk-button' },
);

has_page done => (
    tags => { hide => 1 },
    title => 'Submit',
    template => 'switchout/confirmation.html',
);

has_field start => ( type => 'Submit', value => 'Start', element_attr => { class => 'govuk-button' } );
has_field continue => ( type => 'Submit', value => 'Continue', element_attr => { class => 'govuk-button' } );

# this makes sure that if any of the child fields have errors we mark the date
# as invalid, even if it's technically a valid date. This is mostly to catch
# range errors on the year. Otherwise we get an error at the top of the page
# but the field isn't highlighted
sub validate_datetime {
    my ($form, $field) = @_;

    if ($field->value < DateTime->today(time_zone => FixMyStreet->local_time_zone)) {
        $field->add_error("You cannot enter a date in the past");
    }

    return if scalar @{ $field->errors };
    my $valid = 1;
    for my $child ( @{ $field->{fields} } ) {
        $valid = 0 if scalar @{ $child->errors };
    }

    $field->add_error("Please enter a valid date") unless $valid;
}

sub generate_pdf {
    my ($self, $report) = @_;

    my $form = $self->new(
        page_name => 'intro',
        saved_data => $report->extra,
        no_preload => 1,
    );

    require FixMyStreet::PDF;
    my $pdf = FixMyStreet::PDF->new(
        title => $report->title . ', FMS' . $report->id,
        font => 'Johnston100',
    );

    # Simplest solution, have a template that has the HTML in,
    # and let it place it all. This works, but has orphans.
    #my $input = $c->render_fragment('licence/summary_pdf.html');
    #$pdf->plot_line(undef, 'black', $input);

    # So instead, generate the PDF line by line and check for
    # orphan headings as we go

    my ($rc, $next_y);
    ($rc, $next_y) = $pdf->plot_line($next_y, 'black', '<h1>' . $form->title . '</h1>');
    ($rc, $next_y) = $pdf->plot_line($next_y, 'black', '<p>Application reference: FMS' . $report->id . '</p>');
    ($rc, $next_y) = $pdf->plot_line($next_y, 'black', '<p>Date of application: ' . $report->created->strftime('%d/%m/%Y') . '</p>');

    foreach my $page (@{$form->fields_for_display}) {
        next if $page->{hide};
        next if $page->{stage} eq 'intro' || $page->{stage} eq 'done';

        my $page_title = "<h2>$page->{title}</h2>";
        my ($rc, $post_title_y) = $pdf->plot_line($next_y, 'white', $page_title);
        if ($rc) {
            # Want to start heading on new page
            $next_y = undef;
        }

        my $first_field = 1;
        foreach my $field (@{$page->{fields}}) {
            next if $field->{hide};
            my $line = "<p style='margin-top:6pt'><strong>$field->{desc}";
            $line .= ':' unless !$field->{desc} || $field->{desc} =~ /[?:.]$/;
            $line .= "</strong>";
            $line .= $field->{name} eq 'terms_accepted' ? "\n" : ' ';
            $line .= "$field->{pretty}</p>";
            $line =~ s/\n/<\/p><p>/g; # Term checkboxes

            if ($first_field) {
                $first_field = 0;
                if ($post_title_y) {
                    # Can we fit the line of text in after the heading?
                    ($rc) = $pdf->plot_line($post_title_y, 'white', $line);
                    if ($rc) {
                        # Heading would be an orphan, want to start it on new page
                        $next_y = undef;
                    }
                }
                ($rc, $next_y) = $pdf->plot_line($next_y, '#0019A8', $page_title);
            }
            ($rc, $next_y) = $pdf->plot_line($next_y, 'black', $line);
        }
    }

    return $pdf->to_string;
}

1;
