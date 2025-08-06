package FixMyStreet::App::Form::Waste::Bulky::Bexley;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste::Bulky';

has_page intro => (
    intro => 'bulky/intro.html',
    fields => ['continue'],
    update_field_list => sub {
        my $form = shift;
        my $data = $form->saved_data;
        $data->{_pension_check} = 1;
        return {};
    },
    next => 'about_you',
);

has_page pension_check => (
    fields => ['pension', 'disability', 'continue'],
    next => 'choose_date_earlier',
);

has_field pension => (
    type => 'Select',
    widget => 'RadioGroup',
    required => 1,
    label => 'Does anyone at the property receive a state pension?',
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

has_field disability => (
    type => 'Select',
    widget => 'RadioGroup',
    required => 1,
    label => 'Do you have a physical disability?',
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

has_page location => (
    title    => 'Location details',
    intro => 'bulky/location.html',
    fields   =>
        [ 'location', 'parking', 'parking_extra_details', 'location_photo', 'location_photo_fileid', 'continue' ],
    next => 'summary',
    field_ignore_list => sub {
        return ['location_photo', 'location_photo_fileid'];
    },
);

has_field location => (
    label => 'Where will you leave the items?',
    type => 'Select',
    required => 1,
    widget => 'RadioGroup',
    options_method => sub {
        my $self = shift;
        my $data = $self->form->saved_data;
        my @options = (
            'Front garden or driveway',
            'Rear of property (only if no front access)',
            'Side of property (only if no front access)',
            'Inside garage (left open)',
            'Inside or alongside communal bin-store (flats only)',
            'In the car park (flats only)',
            'In the bulky waste store (flats only)',
            'Report to office (flats or schools only)',
        );
        if ($data->{disability} eq 'Yes') {
            push @options,
                'Inside the property (ground-floor only)';
        }
        @options = map { { label => $_, value => $_ } } @options;
        return \@options;
    },
);

has_field parking => (
    label => 'Are there any parking restrictions outside the property?',
    type => 'Select',
    required => 1,
    widget => 'RadioGroup',
    options => [
        {   label     => 'No',
            value     => 'No',
            data_hide => '#form-parking_extra_details-row',
        },
        {   label => 'Yes – single yellow lines',
            value => 'Yes - single yellow lines',
            data_show => '#form-parking_extra_details-row',
        },
        {   label     => 'Yes – double yellow lines',
            value     => 'Yes - double yellow lines',
            data_hide => '#form-parking_extra_details-row',
        },
        {   label     => 'Yes – red lines',
            value     => 'Yes - red lines',
            data_hide => '#form-parking_extra_details-row',
        },
        {   label => 'Yes – controlled parking zone',
            value => 'Yes - controlled parking zone',
            data_show => '#form-parking_extra_details-row',
        },
        {   label => 'Yes – resident permit holders only',
            value => 'Yes - resident permit holders only',
            data_show => '#form-parking_extra_details-row',
        },
    ],
);

has_field parking_extra_details => (
    label => 'Tell us about the parking restrictions (up to 250 characters)',
    type => 'Text',
    widget => 'Textarea',
    maxlength => 250,
    required_when => {
        parking => sub {
            $_[1]->form->field('parking')->value
                =~ /^Yes - (single yellow lines|controlled parking zone|resident permit holders only)$/;
        },
    },
    tags => {
        hint => 'Include details such as time restrictions etc.',
        initial_hidden => 1,
    },
);

1;
