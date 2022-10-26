package FixMyStreet::App::Form::Waste::Bulky;

use utf8;
use DateTime::Format::Strptime;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste';

# XXX Remove hardcoded number & fetch from config
use constant MAX_ITEMS => 5;

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

has_page add_items => (
    fields   => [ 'continue', map {"item_$_"} ( 1 .. MAX_ITEMS ) ],
    template => 'waste/bulky/items.html',
    title    => 'Add items for collection',
    next     => 'location',
);

has_page location => (
    title => 'Location details',
    fields => ['location', 'location_photo', 'location_photo_fileid', 'continue'],
    next => 'summary',
);

has_page summary => (
    fields => ['submit', 'tandc'],
    title => 'Submit collection booking',
    template => 'waste/bulky/summary.html',
    next => 'payment',
);

has_page payment => ( # XXX need to actually take payment
    title => 'Payment successful',
    fields => [ 'continue' ],
    next => 'done',
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
            value => $_->{date},
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
    $_[0]->c->cobrand->call_hook('bulky_items_master_list');
}

has items_by_category => (
    is      => 'ro',
    isa     => 'HashRef',
    lazy    => 1,
    builder => '_build_items_by_category',
);

sub _build_items_by_category {
    my $self = shift;

    my %hash;
    for my $item ( @{ $self->items_master_list } ) {
        push @{ $hash{ $item->{category} } }, $item->{name};
    }
    return \%hash;
}

# Hash of item names mapped to extra text
has items_extra_text => (
    is      => 'ro',
    isa     => 'HashRef',
    lazy    => 1,
    builder => '_build_items_extra_text',
);

sub _build_items_extra_text {
    my $self = shift;

    my %hash;
    for my $item ( @{ $self->items_master_list } ) {
        $hash{ $item->{name} } = $item->{message} if $item->{message};
    }
    return \%hash;
}

sub format_item_string {
    my ( $self, $str ) = @_;
    return lc $str =~ s/\W+/_/gr;
}

sub field_list {
    my $self = shift;

    my @field_list;

    for my $num ( 1 .. MAX_ITEMS ) {
        push @field_list,
            "item_$num" => {
            type     => 'Compound',
            id       => "item_$num",
            };

        push @field_list, "item_$num.item" => {
            type           => 'Select',
            label          => "Item $num",
            id             => "item_$num.item",
            empty_select   => 'Please select an item',
            tags           => { autocomplete => 1 },
            options_method => sub {
                my $field = shift;

                # JS autocomplete ignores optgroups, but we want them in case
                # a user has JS disabled.
                # In order to display under optgroups, we have to build
                # data structures like the following:
                # {   group   => 'First Group',
                #     options => [
                #         { value => 1, label => 'One' },
                #         { value => 2, label => 'Two' },
                #         { value => 3, label => 'Three' },
                #     ],
                # },
                my @option_groups;

                for my $cat ( sort keys %{ $field->form->items_by_category } )
                {
                    my @options;

                    for my $name (
                        @{ $field->form->items_by_category->{$cat} } )
                    {
                        push @options => {
                            label => $name,
                            value => $name,
                        };
                    }

                    push @option_groups => {
                        group   => $cat,
                        options => \@options,
                    };
                }

                return \@option_groups;
            },
        };

        push @field_list => (
            "item_$num.photo" => {
                type  => 'Photo',
                label => 'Upload image (optional)',
                tags  => { max_photos => 1 },
                # XXX Limit to JPG etc.
                # XXX Save to DB
            },
            "item_$num.photo_fileid" => {
                type                => 'FileIdPhoto',
                num_photos_required => 0,
                linked_field        => "item_$num.photo",
            },
        );
    }

    return \@field_list;
}

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

sub validate {
    my $self = shift;

    if ( $self->current_page->name =~ /choose_date/ ) {
        my $next_page
            = $self->current_page->next->( undef, $self->c->req->params );

        if ( $next_page eq 'add_items' ) {
            $self->field('chosen_date')
                ->add_error('Available dates field is required')
                if !$self->field('chosen_date')->value;
        }
    }

    if ( $self->current_page->name eq 'add_items' ) {
        for my $num ( 1 .. MAX_ITEMS ) {
            my $base_field = $self->field("item_$num");

            # Make sure at least item_1 has input
            $base_field->add_error('Please select an item')
                if $num == 1 && !$base_field->field('item')->value;

            # XXX Image upload
        }
    }
}

after 'process' => sub {
    my $self = shift;

    # XXX Do we want to let the user know there are no available dates
    # much earlier in the journey?

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
