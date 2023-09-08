package FixMyStreet::App::Form::Waste::Bulky;

use utf8;
use DateTime::Format::Strptime;
use HTML::FormHandler::Moose;
use JSON::MaybeXS;
extends 'FixMyStreet::App::Form::Waste';

has_page intro => (
    title => 'Book bulky goods collection',
    intro => 'bulky/intro.html',
    fields => ['continue'],
    update_field_list => sub {
        my $form = shift;
        my $data = $form->saved_data;
        my $c = $form->c;
        $data->{_residency_check} = 1 if $c->cobrand->moniker eq 'peterborough';
        return {};
    },
    next => sub {
        return 'residency_check' if $_[0]->{_residency_check};
        'about_you';
    }
);

has_page residency_check => (
    title => 'Book bulky goods collection',
    fields => ['resident', 'continue'],
    next => sub { $_[0]->{resident} eq 'Yes' ? 'about_you' : 'cannot_book' },
);

has_page cannot_book => (
    fields => [],
    intro => 'bulky/cannot_book.html',
    title => 'Book bulky goods collection',
);

has_page about_you => (
    fields => ['name', 'email', 'phone', 'continue'],
    title => 'About you',
    next => 'choose_date_earlier',
);

with 'FixMyStreet::App::Form::Waste::AboutYou';

has_page choose_date_earlier => (
    fields => [
        'continue',         'chosen_date',
        'show_later_dates',
        ],
    title => 'Choose date for collection',
    template => 'waste/bulky/choose_date.html',
    next => sub {
        ( $_[1]->{later_dates} )
            ? 'choose_date_later'
            : 'add_items';
    },
);

has_page choose_date_later => (
    fields => [
        'continue',         'chosen_date',
        'show_earlier_dates',
        ],
    title => 'Choose date for collection',
    template => 'waste/bulky/choose_date.html',
    next => sub {
        ( $_[1]->{earlier_dates} )
            ? 'choose_date_earlier'
            : 'add_items';
    },
);

has_page location => (
    title    => 'Location details',
    fields   =>
        [ 'location', 'location_photo', 'location_photo_fileid', 'continue' ],
    next => 'summary',
    update_field_list => sub {
        my ($form) = @_;
        my $fields = {};
        $form->update_photo('location_photo', $fields);
        return $fields;
    },
);

has_page summary => (
    fields => ['submit', 'tandc'],
    title => 'Submit collection booking',
    template => 'waste/bulky/summary.html',
    next => sub { $_[0]->{no_slots} ? 'choose_date_earlier' : 'done' },
    update_field_list => sub {
        my $form = shift;
        my $c = $form->c;
        my $label = FixMyStreet::Template::SafeString->new('I have read the <a href="' . $c->cobrand->call_hook('bulky_tandc_link') . '" target="_blank">bulky waste collection</a> page on the council’s website');
        return {
            tandc => { option_label => $label }
        };
    },
    # Return to 'Choose date' page if slot has been taken in the meantime.
    # Otherwise, proceed to payment.
    pre_finished => sub {
        my $form = shift;
        my $c = $form->c;

        my $slot_still_available
            = $c->cobrand->call_hook(
            check_bulky_slot_available => $form->saved_data->{chosen_date} );

        return 1 if $slot_still_available;

        # Clear date cache so user gets updated selection
        $c->cobrand->call_hook(
            clear_cached_lookups_bulky_slots => $c->stash->{property}{uprn} );

        $c->stash->{flash_message} = 'choose_another_date';
        $form->saved_data->{no_slots} = 1;
        return 0;
    },
    finished => sub {
        return $_[0]->wizard_finished('process_bulky_data');
    },

);

has_page done => (
    title => 'Collection booked',
    template => 'waste/bulky/confirmation.html',
);


has_field continue => (
    type => 'Submit',
    value => 'Continue',
    element_attr => {
        class      => 'govuk-button',
        formaction => '?',
    },
    order => 999,
);

has_field submit => (
    type => 'Submit',
    value => 'Continue to payment',
    tags => { hint => "You will be redirected to the council’s card payments provider." },
    element_attr => { class => 'govuk-button' },
    order => 999,
);

has_field resident => (
    type => 'Select',
    widget => 'RadioGroup',
    required => 1,
    label => 'Do you live at the property or are you booking on behalf of the householder?',
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
);

has_field chosen_date => (
    type                 => 'Select',
    widget               => 'RadioGroup',
    label                => 'Available dates',
    no_option_validation => 1,
    options_method => sub {
        my $self = shift;
        my $form = $self->form;
        my $c    = $form->c;

        my @dates;
        if ($form->current_page->name eq 'choose_date_later') {
            @dates = _get_dates( $c, $c->stash->{last_earlier_date} );
        } else {
            @dates = _get_dates($c);
            $c->stash->{last_earlier_date} = $dates[-1]{value} if @dates;
        }

        return \@dates;
    },
);

sub _get_dates {
    my ( $c, $last_earlier_date ) = @_;

    my $parser = DateTime::Format::Strptime->new( pattern => '%FT%T' );
    my @dates  = grep {$_} map {
        my $dt = $parser->parse_datetime( $_->{date} );
        $dt
            ? {
            label => $dt->strftime('%d %B'),
            value => $_->{reference} ? $_->{date} . ";" . $_->{reference} . ";" . $_->{expiry} : $_->{date},
            }
            : undef
        } @{
        $c->cobrand->call_hook(
            'find_available_bulky_slots', $c->stash->{property},
            $last_earlier_date,
        )
        };

    return @dates;
}

has_field show_later_dates => (
    type         => 'Submit',
    value        => 'Show later dates',
    element_attr => {
        class          => 'govuk-button',
        formaction     => '?later_dates=1',
    },
    order => 998,
);

has_field show_earlier_dates => (
    type         => 'Submit',
    value        => 'Show earlier dates',
    element_attr => {
        class          => 'govuk-button',
        formaction     => '?earlier_dates=1',
    },
    order => 998,
);

# Item selection code

# List as fetched from cobrand, before munging
has items_master_list => (
    is      => 'ro',
    isa     => 'ArrayRef',
    lazy    => 1,
    builder => '_build_items_master_list',
);

sub _build_items_master_list {
    [ sort { lc $a->{name} cmp lc $b->{name} }
            @{ $_[0]->c->cobrand->call_hook('bulky_items_master_list') } ];
}

# Hash of item names mapped to extra text
has items_extra => (
    is      => 'ro',
    isa     => 'HashRef',
    lazy    => 1,
    builder => '_build_items_extra',
);

sub _build_items_extra {
    shift->c->cobrand->bulky_items_extra;
}

has_field tandc => (
    type => 'Checkbox',
    required => 1,
    label => 'Terms and conditions',
    option_label => '' # Generated in update_field_list of page summary
);

has_field location => (
    type => 'Text',
    widget => 'Textarea',
    label => "Please provide the exact location where the items will be left (e.g., On the driveway; To the left of the front door; By the front hedge, etc.)",
);

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
    build_label_method => sub {
        my $self = shift;

        return 'Please check the <a href="' . $self->parent->{c}->cobrand->call_hook('bulky_tandc_link') . '" target="_blank">Terms & Conditions</a> for information about when and where to leave your items for collection.' . "\n\n\n"
        . 'Help us by attaching a photo of where the items will be left for collection.'
    }
);

sub validate {
    my $self = shift;

    $self->next::method();

    if ( $self->current_page->name =~ /choose_date/ ) {
        my $next_page
            = $self->current_page->next->( undef, $self->c->req->params );

        if ( $next_page eq 'add_items' ) {
            $self->field('chosen_date')
                ->add_error('Available dates field is required')
                if !$self->field('chosen_date')->value;
        }
    }

    if ($self->current_page->name eq 'add_items') {
        my $max_items = $self->c->cobrand->bulky_items_maximum;
        my %given;
        for my $num ( 1 .. $max_items ) {
            my $val = $self->field("item_$num")->value or next;
            $given{$val}++;
        }
        my %max = map { $_->{name} => $_->{max} } @{ $self->items_master_list };
        foreach (sort keys %given) {
            if ($max{$_} && $given{$_} > $max{$_}) {
                $self->add_form_error("Too many of item: $_");
            }
        }
    }
}

after 'process' => sub {
    my $self = shift;

    # XXX Do we want to let the user know there are no available dates
    # much earlier in the journey?

    # Hide 'show_later_dates' for certain cobrands
    if ( $self->c->cobrand->call_hook('bulky_hide_later_dates') ) {
        $self->field('show_later_dates')->inactive(1);
    }

    # Hide certain fields if no date options
    if ( $self->current_page->name eq 'choose_date_earlier'
        && !@{ $self->field('chosen_date')->options } )
    {
        $self->field('chosen_date')->inactive(1);
        $self->field('show_later_dates')->inactive(1);
        $self->field('continue')->inactive(1);
    }

    if ( $self->current_page->name eq 'choose_date_later'
        && !@{ $self->field('chosen_date')->options } )
    {
        $self->field('chosen_date')->inactive(1);
        $self->field('continue')->inactive(1);
    }
};

1;
