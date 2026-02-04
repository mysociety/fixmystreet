package FixMyStreet::App::Form::Licence::Base;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Wizard';
use List::MoreUtils qw(firstidx);

# Shared field roles
with 'FixMyStreet::App::Form::Licence::Fields::Location';
with 'FixMyStreet::App::Form::Licence::Fields::Applicant';
with 'FixMyStreet::App::Form::Licence::Fields::Contractor';
with 'FixMyStreet::App::Form::Licence::Fields::TemporaryProhibition';

=head1 NAME

FixMyStreet::App::Form::Licence - shared pages and fields for licence forms

=head1 DESCRIPTION

Functionality shared between all the TfL Licence forms.

=cut

has upload_subdir => (
    is => 'ro',
    lazy => 1,
    default => sub {
        return 'tfl-licence-' . $_[0]->type;
    },
);

has default_page_type => ( is => 'ro', isa => 'Str', default => 'Wizard' );

has finished_action => ( is => 'ro', default => 'process_licence' );

has '+is_html5' => ( default => 1 );

# The summary page loops through all the pages to display everything.
# The parent pages are being displayed first, so re-jig them into a
# better place. Nicer way of doing this? Manually setting order?
after after_build => sub {
    my $form = shift;
    my @pages = $form->all_pages;

    # Move date/applicant/contractor pages after location
    my $page_location = firstidx { $_->{name} eq 'location' } @pages;
    my $page_dates = firstidx { $_->{name} eq 'dates' } @pages;
    splice(@pages, $page_location-2, 0, splice(@pages, $page_dates, 3));

    # Move payment/summary pages after uploads (the end)
    my $page_upload = firstidx { $_->{name} eq 'uploads' } @pages;
    push @pages, splice(@pages, $page_dates, 2);

    # For mobile apparatus, move special date pages next to dates
    my $page_date_choice = firstidx { $_->{name} eq 'date_choice' } @pages;
    if ($page_date_choice > -1) {
        my $page_dates = firstidx { $_->{name} eq 'dates' } @pages;
        splice(@pages, $page_dates, 0, splice(@pages, $page_date_choice, 2));
    }

    $form->pages(\@pages);
};

=head2 Dates

Provides standard date page and fields used by all TfL licence forms:
proposed_start_date, proposed_duration

Includes validation:
- Start date must be at least 4 weeks from today

=cut

has_page dates => (
    fields => ['proposed_start_date', 'proposed_duration', 'year_warning', 'continue'],
    title => 'Proposed working dates',
    intro => 'dates.html',
    next => sub {
        my ($data, $params, $form) = @_;
        return 'times' if $form->type eq 'pit-lane';
        return 'applicant';
    },
    tags => {
        hide => sub {
            my $self = shift;
            my $form = $self->form;
            return $form->type eq 'mobile-apparatus';
        },
    },
);

has_field proposed_start_date => (
    type => 'DateTime',
    label => 'Proposed start date',
    required => 1,
    tags => { hint => 'Working dates must be set in four‑weekly periods. For example, 1/1/2026 to 29/1/2026.' },
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
    },
);

has_field 'proposed_start_date.day' => ( type => 'MonthDay' );
has_field 'proposed_start_date.month' => ( type => 'Month' );
has_field 'proposed_start_date.year' => ( type => 'Year' );

has_field proposed_duration => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Number of weeks required',
    required => 1,
    validate_method => sub {
        my $field = shift;
        return if $field->has_errors; # Called even if already failed

        my $saved_data = $field->form->saved_data;
        my $weeks = $field->value;

        my $start_date = $field->form->field('proposed_start_date');
        if (!$start_date->has_errors) {
            my $end = $start_date->value->clone->add(weeks => $weeks);
            $saved_data->{proposed_end_date} = $end;
        }

        # Make sure if weeks is set to 2, we set the type to mobile tower
        if ($weeks == 2) {
            $saved_data->{scaffold_type} = 'Scaffold (Mobile Tower)';
        }
    },
);

my @week_options = (
    { label => '2 weeks', value => 2 },
    { label => '4 weeks', value => 4 },
    { label => '6 weeks', value => 6 },
    { label => '8 weeks', value => 8 },
    { label => '10 weeks', value => 10 },
    { label => '12 weeks', value => 12 },
    { label => '14 weeks', value => 14 },
    { label => '16 weeks', value => 16 },
    { label => '18 weeks', value => 18 },
    { label => '20 weeks', value => 20 },
    { label => '22 weeks', value => 22 },
    { label => '24 weeks', value => 24 },
    { label => '26 weeks', value => 26 },
    { label => '28 weeks', value => 28 },
    { label => '32 weeks', value => 32 },
    { label => '36 weeks', value => 36 },
    { label => '40 weeks', value => 40 },
    { label => '44 weeks', value => 44 },
    { label => '48 weeks', value => 48 },
    { label => '52 weeks', value => 52 },
);

sub options_proposed_duration {
    my $type = $_[0]->type;
    my @options;
    if ($type eq 'builders-skip') {
        @options = grep { $_->{value} <= 26 } @week_options;
    } elsif ($type eq 'pit-lane') {
        @options = @week_options;
    } else {
        @options = grep { !($_->{value} % 4) } @week_options;
    }
    # Scaffold and Building Materials have a 2 week option
    if ($type eq 'scaffold') {
        unshift @options, { label => '2 weeks (mobile scaffold only)', value => 2 };
    } elsif ($type eq 'building-materials') {
        unshift @options, { label => '2 weeks', value => 2 };
    }
    return @options;
}

has_field year_warning => ( type => 'Notice', label => '<span id="js-proposed_end_date"></span> All licences are limited to a duration of one year.', required => 0, widget => 'NoRender' );

=head2 Applicant/contractor

=cut

# ==========================================================================
# About You (Applicant) fields from Fields::Applicant role
# ==========================================================================
has_page applicant => (
    fields => [
        'organisation',
        'name',
        'job_title',
        'address',
        'email',
        'phone',
        'phone_24h',
        'continue'
    ],
    title => 'Applicant details',
    intro => 'applicant.html',
    next => sub { $_[2]->next_after_applicant }
);

sub next_after_applicant { 'contractor' }

# ==========================================================================
# About You (Principal Contractor)
# Fields from Fields::Contractor role
# ==========================================================================
has_page contractor => (
    fields => [
        'contractor_same_as_applicant',
        'contractor_organisation',
        'contractor_contact_name',
        'contractor_address',
        'contractor_email',
        'contractor_phone',
        'contractor_phone_24h',
        'contractor_nasc_member',
        'contractor_authorised',
        'continue'
    ],
    field_ignore_list => sub {
        my $page = shift;
        my $form = $page->form;
        my $type = $form->type;
        return [] if $type eq 'scaffold';
        return ['contractor_nasc_member'];
    },
    title => 'Contractor details',
    next => sub { $_[2]->next_after_contractor },
    tags => {
        hide => sub {
            my $self = shift;
            my $form = $self->form;
            return $form->next_after_applicant ne 'contractor';
        },
    },
);

# "Scaffold contractor" on scaffold, or is this okay?
has_field contractor_authorised => (
    type => 'Checkbox',
    label => '',
    option_label => 'I confirm that I am authorised on behalf of the principal contractor named in this application and have been granted full written authority to submit this application on their behalf. I further confirm that all liabilities, insurance requirements, safety obligations, and statutory responsibilities remain with the principal contractor, and that all information supplied has been provided with their consent.',
    validate_method => sub {
        my $self = shift;
        my $same = $self->form->field('contractor_same_as_applicant')->value;
        $self->add_error('Please confirm') if !$self->value && !$same;
    },
    tags => { hide => sub { $_[0]->form->saved_data->{contractor_same_as_applicant} } },
);

# For Scaffold only, ignored by others
has_field contractor_nasc_member => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Is the scaffold contractor a member of a regulated scaffolding association, such as NASC?',
    required => 1,
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

=head2 Payment/summary/done

These are shared for all the forms.

=cut

# ==========================================================================
# Payment
# ==========================================================================
has_page payment => (
    fields => [
        'payment_transaction_id',
        'continue'
    ],
    title => 'Payment',
    intro => 'payment.html',
    next => 'summary',
);

has_field payment_transaction_id => (
    type => 'Text',
    label => 'Transaction ID',
);

sub payment_link { 'LINK' }

# ==========================================================================
# Summary
# ==========================================================================
has_page summary => (
    fields => ['confirmation', 'submit'],
    title => 'Application Summary',
    template => 'licence/summary.html',
    finished => sub {
        my $form = shift;
        my $c = $form->c;
        my $success = $c->forward('process_licence', [ $form ]);
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
    option_label => 'I confirm that the information I have provided in this application is true, complete and accurate to the best of my knowledge. I understand that providing false or misleading information may result in this application being refused or any licence issued being revoked.',
);

has_field submit => (
    type => 'Submit',
    value => 'Submit application',
    element_attr => { class => 'govuk-button' },
);

# ==========================================================================
# Confirmation
# ==========================================================================
has_page done => (
    title => 'Application complete',
    template => 'licence/confirmation.html',
);

# ==========================================================================
# Shared fields
# ==========================================================================
has_field continue => (
    type => 'Submit',
    value => 'Continue',
    order => 999,
    element_attr => { class => 'govuk-button' },
);

__PACKAGE__->meta->make_immutable;

1;
