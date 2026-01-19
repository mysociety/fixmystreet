package FixMyStreet::App::Form::Licence::Fields::Dates;

use utf8;
use HTML::FormHandler::Moose::Role;

=head1 NAME

FixMyStreet::App::Form::Licence::Fields::Dates - Date fields for licence forms

=head1 DESCRIPTION

Provides standard date fields used by all TfL licence forms:
proposed_start_date, proposed_end_date

Includes validation:
- Start date must be at least 4 weeks from today
- End date must be within 1 year from today
- End date must be after start date

=cut

has_field proposed_start_date => (
    type => 'DateTime',
    label => 'Proposed start date',
    required => 1,
    tags => { hint => 'For example, 27 3 2026. Working dates must set in four‑weekly periods' },
    messages => {
        datetime_invalid => 'Please enter a valid date',
    },
    validate_method => sub {
        my $field = shift;
        my $dt = $field->value;
        return unless $dt;

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

has_field proposed_end_date => (
    type => 'DateTime',
    label => 'Proposed end date',
    required => 1,
    tags => { hint => 'For example, 24 4 2026' },
    messages => {
        datetime_invalid => 'Please enter a valid date',
    },
    validate_method => sub {
        my $field = shift;
        my $dt = $field->value;
        return unless $dt;

        my $start_date = $field->form->field('proposed_start_date')->value;
        if ($start_date) {
            my $max_date = $start_date->clone->add(years => 1);
            if ($dt <= $start_date) {
                $field->add_error('End date must be after start date');
            } elsif ($dt > $max_date) {
                $field->add_error('End date must be within 1 year from the start date')
            }
        }
    },
);

has_field 'proposed_end_date.day' => ( type => 'MonthDay' );
has_field 'proposed_end_date.month' => ( type => 'Month' );
has_field 'proposed_end_date.year' => ( type => 'Year' );

1;
