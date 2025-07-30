=head1 NAME

FixMyStreet::App::Form::Waste::Bulky::Shared - shared pages/fields of a bulky collection form

=head1 DESCRIPTION

=cut

package FixMyStreet::App::Form::Waste::Bulky::Shared;

use utf8;
use DateTime::Format::Strptime;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste';
use FixMyStreet::Template::SafeString;

has_page choose_date_earlier => (
    fields => [ 'continue', 'chosen_date', 'show_later_dates' ],
    title => 'Choose date for collection',
    template => 'waste/bulky/choose_date.html',
    next => sub {
        ( $_[1]->{later_dates} )
            ? 'choose_date_later'
            : 'add_items';
    },
);

has_page choose_date_later => (
    fields => [ 'continue', 'chosen_date', 'show_earlier_dates' ],
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
    intro => 'bulky/location.html',
    fields   =>
        [ 'location', 'location_photo', 'location_photo_fileid', 'continue' ],
    next => 'summary',
    field_ignore_list => sub {
        my $page = shift;
        my $c = $page->form->c;
        if ($c->cobrand->bulky_disabled_location_photo) {
            return ['location_photo', 'location_photo_fileid'];
        }
    },
    update_field_list => sub {
        my ($form) = @_;
        my $fields = {};
        if ($form->c->cobrand->bulky_show_location_field_mandatory) {
            $fields->{location} = { required => 1 };
        }
        if ($form->c->cobrand->moniker eq 'kingston' || $form->c->cobrand->moniker eq 'sutton') {
            $fields->{location}{tags}{hint} = 'For example, ‘On the driveway’';
        }

        my $maxlength
            = $form->c->cobrand->call_hook('bulky_location_max_length');
        $fields->{location}{maxlength} = $maxlength if $maxlength;

        return $fields;
    },
);

has_page summary => (
    fields => ['submit', 'tandc', 'payment_method', 'payment_explanation', 'cheque_reference'],
    title => 'Submit collection booking',
    template => 'waste/bulky/summary.html',
    next => sub { $_[0]->{no_slots} ? 'choose_date_earlier' : 'done' },
    field_ignore_list => sub {
        my $page = shift;
        my $c = $page->form->c;

        my $cobrand = $c->cobrand->moniker;
        if ($cobrand ne 'sutton' && $cobrand ne 'kingston' && $cobrand ne 'merton') {
            return ['payment_method', 'payment_explanation', 'cheque_reference'];
        }
        if (!$c->stash->{is_staff}) {
            return ['payment_method', 'payment_explanation', 'cheque_reference'];
        }
        if ($cobrand eq 'merton') {
            return ['cheque_reference'];
        }
        if ($cobrand eq 'kingston' || $cobrand eq 'sutton') {
            return ['payment_explanation'];
        }
    },
    update_field_list => sub {
        my ($form) = @_;
        my $data = $form->saved_data;
        my $new = _renumber_items($data, $form->c->cobrand->bulky_items_maximum);
        %$data = %$new;
        return {};
    },
    # Return to 'Choose date' page if slot has been taken in the meantime.
    # Otherwise, proceed to payment.
    pre_finished => sub {
        my $form = shift;
        my $c = $form->c;

        if ($c->stash->{amending_booking}) {
            my $current_date = $c->cobrand->collection_date($c->stash->{amending_booking});
            return 1 if $current_date eq $form->saved_data->{chosen_date};
        }

        # Some cobrands may set a new chosen_date on the form
        my $slot_still_available = $c->cobrand->call_hook(
            check_bulky_slot_available => $form->saved_data->{chosen_date},
            form                       => $form,
        );

        return 1 if $slot_still_available;

        # Clear date cache so user gets updated selection
        $c->cobrand->call_hook(
            clear_cached_lookups_bulky_slots => $c->stash->{property}{id} );

        $c->stash->{flash_message} = 'choose_another_date';
        $form->saved_data->{no_slots} = 1;
        return 0;
    },
    finished => sub {
        if ($_[0]->c->stash->{amending_booking}) {
            return $_[0]->wizard_finished('process_bulky_amend');
        } else {
            return $_[0]->wizard_finished('process_bulky_data');
        }
    },
);

has_page done => (
    title => 'Collection booked',
    template => 'waste/bulky/confirmation.html',
);

with 'FixMyStreet::App::Form::Waste::Billing';

has_field continue => (
    type => 'Submit',
    value => 'Continue',
    element_attr => {
        class      => 'govuk-button',
        formaction => '?',
    },
    order => 999,
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

    my %dates_booked;
    foreach (@{$c->stash->{pending_bulky_collections} || []}) {
        my $date = $c->cobrand->collection_date($_);
        $dates_booked{$date} = 1;
    }
    my $existing_date;
    if (my $amend = $c->stash->{amending_booking}) {
        # Want to allow amendment without changing the date
        $existing_date = $c->cobrand->collection_date($amend);
        delete $dates_booked{$existing_date};
    }

    my $pattern = '%FT%T';
    $pattern = '%F' if $c->cobrand->moniker eq 'bexley'; # Move more to this over time?
    my $parser = DateTime::Format::Strptime->new( pattern => $pattern );
    my @dates  = grep {$_} map {
        my $dt = $parser->parse_datetime( $_->{date} );
        my $label = $c->cobrand->moniker eq 'brent' ? '%d %B' : '%A %e %B';
        $dt
            ? {
            label => $c->cobrand->call_hook( 'bulky_date_label', $dt )
                || $dt->strftime($label),
            value => $_->{reference} ? $_->{date} . ";" . $_->{reference} . ";" . $_->{expiry} : $_->{date},
            disabled => $dates_booked{$_->{date}},
            # The default behaviour in the fields.html template is to mark a radio
            # button as checked if the existing value matches the option value. However,
            # for Echo bulky dates the option value is a concatenation of the date and
            # the reference, so the comparison won't ever match because we've got a new
            # set of references. So we need to do the comparison here of just the dates
            # and set the selected flag accordingly.
            selected => $existing_date && $existing_date eq $_->{date},
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
    build_option_label_method => sub {
        my $form = $_[0]->form;
        my $c = $form->c;
        my $link = $c->cobrand->call_hook('bulky_tandc_link');
        my $label;
        if ($c->cobrand->moniker eq 'sutton') {
            $label = 'I have read the <a href="' . $link . '" target="_blank">terms and conditions</a> of the service on the council’s website and agree to them.';
        } elsif ($c->cobrand->moniker eq 'bromley') {
            $label = '&bull; I confirm that the bulky waste items will be available from 7.00am on the day of collection
<br>&bull; I confirm the bulky waste items will be left outside at the front of the property but not on the public highway, in an easy accessible location.
<br>&bull; I confirm I understand that items cannot be collected from inside the property
<br>&bull; I confirm I have read the information for the <a href="' . $link . '" target="_blank">bulky waste service</a>';
        } elsif ($c->cobrand->moniker eq 'brent') {
            $label = 'I have read and agree to the <a href="' . $link . '" target="_blank">terms and conditions</a> and understand any additional items presented that do not meet the terms and conditions will not be collected';
        } elsif ($c->cobrand->moniker eq 'bexley') {
            $label = << 'HERE';
&bull; I understand that collections can take place any time after 6am on the chosen collection day. Items must be accessible at the location given and left in a neat and safe manner. Items cannot be left for collection on the public highway.
<br>
&bull; I understand that cancellations are accepted up to one working day before the chosen collection day. Bookings cannot be altered once payment is taken so changes can only be made by cancelling and rebooking.
<br>
&bull; I understand that only the items added to the booking will be taken and any additional items will be left.
<br>
&bull; I understand I may be subject to further charges if proof of pension cannot be provided when requested.
<br>
&bull; I confirm that the submitted information is current and correct, and any misrepresentations could lead to a cancellation of the arranged service without refund.
HERE
        } else {
            $label = 'I have read the <a href="' . $link . '" target="_blank">bulky waste collection</a> page on the council’s website';
        }
        $label = FixMyStreet::Template::SafeString->new($label);
        return $label;
    },
);

has_field location => (
    type => 'Text',
    widget => 'Textarea',
    build_label_method => sub {
        return shift->parent->{c}->cobrand->call_hook('bulky_location_text_prompt');
    },
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
        return shift->parent->{c}->cobrand->call_hook('bulky_location_photo_prompt');
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

    my $cobrand = $self->c->cobrand;
    if ($self->current_page->name eq 'add_items') {
        my $max_items = $cobrand->bulky_items_maximum;
        my %given;

        my $points = 0;
        my %points = map { $_->{name} => $_->{points} } @{ $cobrand->bulky_items_master_list };

        for my $num ( 1 .. $max_items ) {
            my $val = $self->field("item_$num")->value or next;
            $given{$val}++;
            $points += $points{$val} if $points{$val};
        }
        if (!%given) {
            $self->add_form_error("Please select an item");
        }
        my %max = map { $_->{name} => $_->{max} } @{ $self->items_master_list };
        foreach (sort keys %given) {
            if ($max{$_} && $given{$_} > $max{$_}) {
                $self->add_form_error("Too many of item: $_");
            }
        }

        # Points need to check maximum
        if ($cobrand->bulky_points_per_item_pricing) {
            my $levels = $cobrand->bulky_pricing_model($self->saved_data);
            my $total = $cobrand->bulky_points_to_price($points, $levels);
            if ($total eq 'max') {
                $self->add_form_error(
                    "You have added too many items. Please remove some items to proceed."
                );
            }
        }

        if ($self->{c}->cobrand->moniker eq 'brent') {
            my %category_count;
            for my $name (keys %given) {
                for my $list_item (@{ $self->items_master_list }) {
                    if ($list_item->{'name'} eq $name) {
                        if ($list_item->{'category'}) {
                            $category_count{$list_item->{'category'}} += $given{$name};
                        } else {
                            $category_count{$list_item->{'name'}} += $given{$name};
                        }
                    }
                }
            }
            if (scalar keys %category_count > 3) {
                $self->add_form_error("Too many categories: maximum of 3 types");
            }
            if (scalar $category_count{'Small electrical items'} && scalar $category_count{'Small electrical items'} > 4) {
                $self->add_form_error("Too many small electrical items: maximum 4");
            }
        }
    }

    if ($self->current_page->name eq 'summary' && $self->c->stash->{amending_booking}) {
        my $old = $cobrand->waste_reconstruct_bulky_data($self->c->stash->{amending_booking});
        my $new = $self->saved_data;
        my $max_items = $cobrand->bulky_items_maximum;
        my $same = 1;
        my @fields = qw(chosen_date location location_photo);
        push @fields, map { ("item_$_", "item_photo_$_") } 1 .. $max_items;
        foreach (@fields) {
            my $new = $new->{$_} || '';
            if ($_ eq 'chosen_date') {
                $new =~ s/;.*//; # Strip ref+expiry if present (Echo)
            }
            $same = 0 if ($old->{$_} || '') ne $new;
            last unless $same;
        }
        if ($same) {
            $self->add_form_error("You have not changed anything about your booking");
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

=head2 _renumber_items

This function is used to make sure that the incoming item data uses 1, 2, 3,
... in case the user had deleted a middle item and sent us 1, 3, 4, 6, ...

=cut

sub _renumber_items {
    my ($data, $max) = @_;

    my $c = 1;
    my %items;
    for (1..$max) {
        next unless $data->{"item_$_"};
        $items{"item_$c"} = $data->{"item_$_"};
        $items{"item_notes_$c"} = $data->{"item_notes_$_"};
        $items{"item_photo_$c"} = $data->{"item_photo_$_"};
        $c++;
    }
    my $data_itemless = { map { $_ => $data->{$_} } grep { !/^item_(notes_|photo_)?\d/ } keys %$data };
    $data = { %$data_itemless, %items };

    return $data;
}

1;
