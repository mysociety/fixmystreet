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
    label => 'Is anyone at the property in receipt of a state pension?',
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
        [ 'location', 'parking', 'location_photo', 'location_photo_fileid', 'continue' ],
    next => 'summary',
    field_ignore_list => sub {
        return ['location_photo', 'location_photo_fileid'];
    },
);

has_field location => (
    label => 'Where can the items be left for collection?',
    type => 'Select',
    required => 1,
    widget => 'RadioGroup',
    options_method => sub {
        my $self = shift;
        my $data = $self->form->saved_data;
        my @options = (
            { label => 'Front garden or driveway', value => 'Front garden or driveway' },
            { label => 'Rear garden (access via side gate)', value => 'Rear garden (access via side gate)' },
            { label => 'Rear garden (access via rear gate)', value => 'Rear garden (access via rear gate)' },
            { label => 'Inside / alongside communal bin-store', value => 'Inside / alongside communal bin-store' },
            { label => 'Rear of property (accessed via road or alleyway)', value => 'Rear of property (accessed via road or alleyway)' },
            { label => 'Inside garage (left open)', value => 'Inside garage (left open)' },
            { label => 'In the car park (flats only)', value => 'In the car park (flats only)' },
            { label => 'In the drying area (flats only)', value => 'In the drying area (flats only)' },
            { label => 'In the bulky waste store (flats only)', value => 'In the bulky waste store (flats only)' },
            { label => 'Report to office (flats/ schools only)', value => 'Report to office (flats/ schools only)' },
        );
        if ($data->{disability} eq 'Yes') {
            push @options,
                { label => '(Disability yes) Some other option TBC', value => 'Some other option TBC' };
        }
        return \@options;
    },
);

has_field parking => (
    label => 'Are there any parking restrictions outside the property?',
    type => 'Select',
    required => 1,
    widget => 'RadioGroup',
    options => [
        { label => 'No', value => 'No' },
        { label => 'Yes – Single Yellow Lines', value => 'Yes - Single Yellow Lines' },
        { label => 'Yes – Double Yellow Lines', value => 'Yes - Double Yellow Lines' },
        { label => 'Yes – Red Lines', value => 'Yes - Red Lines' },
        { label => 'Yes – Controlled Parking Zone', value => 'Yes - Controlled Parking Zone' },
        { label => 'Yes – Resident Permit Holders Only', value => 'Yes - Resident Permit Holders Only' },
    ],
);

1;
