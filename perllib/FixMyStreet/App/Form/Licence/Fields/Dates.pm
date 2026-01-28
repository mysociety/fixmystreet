package FixMyStreet::App::Form::Licence::Fields::Dates;

use utf8;
use HTML::FormHandler::Moose::Role;

=head1 NAME

FixMyStreet::App::Form::Licence::Fields::Dates - Date fields for licence forms

=head1 DESCRIPTION

Provides standard date fields used by all TfL licence forms:
proposed_start_date, proposed_duration

Includes validation:
- Start date must be at least 4 weeks from today

=cut

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
    options => [
        { label => '2 weeks (mobile scaffold only)', value => 2 },
        { label => '4 weeks', value => 4 },
        { label => '8 weeks', value => 8 },
        { label => '12 weeks', value => 12 },
        { label => '16 weeks', value => 16 },
        { label => '20 weeks', value => 20 },
        { label => '24 weeks', value => 24 },
        { label => '28 weeks', value => 28 },
        { label => '32 weeks', value => 32 },
        { label => '36 weeks', value => 36 },
        { label => '40 weeks', value => 40 },
        { label => '44 weeks', value => 44 },
        { label => '48 weeks', value => 48 },
        { label => '52 weeks', value => 52 },
    ],

    validate_method => sub {
        my $field = shift;
        return if $field->has_errors; # Called even if already failed

        my $weeks = $field->value;

        my $start_date = $field->form->field('proposed_start_date');
        if (!$start_date->has_errors) {
            my $end = $start_date->value->clone->add(weeks => $weeks);
            my $saved_data = $field->form->saved_data;
            $saved_data->{proposed_end_date} = $end;
        }
    },
);

has_field year_warning => ( type => 'Notice', label => '<span id="js-proposed_end_date"></span> All licences are limited to a duration of one year.', required => 0, widget => 'NoRender' );

1;
