package FixMyStreet::App::Form::Waste::Bulky;

use utf8;
use DateTime::Format::Strptime;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste';

has_page intro => (
    title => 'Book bulky goods collection',
    intro => 'bulky/intro.html',
    fields => ['continue'],
    next => 'residency_check',
);

has_page residency_check => (
    title => 'Book bulky goods collection',
    fields => ['resident', 'continue'],
    next => 'about_you',
);

has_page about_you => (
    fields => ['name', 'email', 'phone', 'continue'],
    title => 'About you',
    next => 'choose_date',
);

with 'FixMyStreet::App::Form::Waste::AboutYou';

has_page choose_date => (
    fields => [ 'continue', 'chosen_date', 'show_later_dates' ],
    title => 'Choose date for collection',
    template => 'waste/bulky/choose_date.html',
    next => sub {
        $_[0]->{continue} ? 'add_items' : 'choose_date';
    },
);

has_page add_items => (
    fields => ['continue', 'item1', 'item2', 'item3', 'item4', 'item5'], # XXX build list dynamically
    title => 'Add items for collection',
    next => 'location',
);

has_page location => (
    title => 'Location details',
    fields => ['location', 'location_photo', 'continue'],
    next => 'summary',
);


has_page summary => (
    fields => ['submit', 'tandc'],
    title => 'Submit collection booking',
    template => 'waste/bulky/summary.html',
    next => 'done',
);

has_page done => (
    title => 'Collection booked',
    template => 'waste/bulky/confirmation.html',
);


has_field continue => (
    type => 'Submit',
    value => 'Continue',
    element_attr => { class => 'govuk-button' },
    order => 999,
);

has_field submit => (
    type => 'Submit',
    value => 'Continue to payment',
    element_attr => { class => 'govuk-button' },
    order => 999,
);

has_field resident => (
    type => 'Select',
    widget => 'RadioGroup',
    required => 1,
    label => 'Are you the resident of this property or booking on behalf of the property resident?',
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

has_field chosen_date => (
    type           => 'Select',
    widget         => 'RadioGroup',
    label          => 'Available dates',
    options_method => sub {
        my $self = shift;
        my $c    = $self->form->c;

        my $parser = DateTime::Format::Strptime->new( pattern => '%FT%T' );

        my @dates = grep {$_} map {
            my $dt = $parser->parse_datetime( $_->{date} );
            $dt
                ? {
                label => $dt->strftime('%d %B'),
                value => $_->{date},
                }
                : undef
            } @{
            $c->cobrand->call_hook(
                'find_available_bulky_slots', $c->stash->{property},
                $c->stash->{start_date},
            )
            };

        # XXX Do we want to let the user know there are no available dates
        # much earlier in the journey?
        if ( !@dates ) {
            $self->inactive(1);
            $self->form->field('continue')->inactive(1);
            $self->form->field('show_later_dates')->inactive(1);
        }
        elsif ( !$c->stash->{start_date} ) {
            $c->stash->{start_date} = $dates[-1]{value};
        } else {
            $self->form->field('show_later_dates')->inactive(1);
        }

        return \@dates;
    },
);

has_field show_later_dates => (
    type => 'Submit',
    value => 'Show later dates',
    element_attr => { class => 'govuk-button' },
    order => 998,
);

has_field tandc => (
    type => 'Checkbox',
    required => 1,
    label => 'Terms and conditions',
    option_label => FixMyStreet::Template::SafeString->new(
        'I agree to the <a href="/about/bulky_terms" target="_blank">terms and conditions</a>',
    ),
);

has_field location => (
    required => 1,
    type => 'Text',
    widget => 'Textarea',
    label => "Please tell us about anything else you feel is relevant",
    tags => {
        hint => "(e.g. 'The large items are in the front garden which can be accessed via the gate.')",
    },
);

sub process_photo {
    my ($form, $field) = @_;

    my $saved_data = $form->saved_data;
    my $fileid = $field . '_fileid';
    my $c = $form->{c};
    $c->forward('/photo/process_photo');
    $saved_data->{$field} = $c->stash->{$fileid};
    $saved_data->{$fileid} = '';
}

has_field location_photo_fileid => (
    type => 'FileIdPhoto',
    num_photos_required => 0,
    linked_field => 'location_photo',
);

has_field location_photo => (
    type => 'Photo',
    tags => {
        max_photos => 1,
    },
    label => 'Help us by attaching a photo of where the items will be left for collection.',
);

# XXX yuck
sub item_field {
    my $i = shift;
    (
        type => 'Select',
        widget => 'Select',
        label => 'Item ' . $i,
        required => $i == 1 ? 1 : 0,
        tags => { last_differs => 1, small => 1, autocomplete => 1 },
        options => [
            # XXX look these up dynamically
            { value => 'chair', label => 'Armchair' },
            { value => 'sofa', label => 'Sofa' },
            { value => 'table', label => 'Table' },
            { value => 'fridge', label => 'Fridge' },
        ],
    )
}

# XXX yuck yuck
has_field item1 => item_field(1);
has_field item2 => item_field(2);
has_field item3 => item_field(3);
has_field item4 => item_field(4);
has_field item5 => item_field(5);

sub validate {
   my $self = shift;
   $self->field('chosen_date')->add_error('Available dates field is required')
       if( $self->field('continue')->input &&
           !$self->field('chosen_date')->has_value);
}

1;
