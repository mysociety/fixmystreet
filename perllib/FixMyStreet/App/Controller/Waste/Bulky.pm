package FixMyStreet::App::Controller::Waste::Bulky;
use Moose;
use namespace::autoclean;

BEGIN { extends 'FixMyStreet::App::Controller::Form' }

use utf8;
use FixMyStreet::App::Form::Waste::Bulky;
use FixMyStreet::App::Form::Waste::Bulky::Amend;
use FixMyStreet::App::Form::Waste::Bulky::Cancel;
use FixMyStreet::App::Form::Waste::SmallItems;
use FixMyStreet::App::Form::Waste::SmallItems::Cancel;

has feature => (
    is => 'ro',
    default => 'waste',
);

has index_template => (
    is => 'ro',
    default => 'waste/form.html'
);

sub setup : Chained('/waste/property') : PathPart('bulky') : CaptureArgs(0) {
    my ($self, $c) = @_;

    $c->detach('/waste/property_redirect') if $c->cobrand->moniker eq 'brent';
    if ( !$c->stash->{property}{show_bulky_waste} ) {
        $c->detach('/waste/property_redirect');
    }
}

sub setup_small : Chained('/waste/property') : PathPart('small_items') : CaptureArgs(0) {
    my ($self, $c) = @_;

    $c->detach('/waste/property_redirect') if $c->cobrand->moniker ne 'brent';
    if ( !$c->stash->{property}{show_bulky_waste} ) {
        $c->detach('/waste/property_redirect');
    }
}

sub bulky_item_options_method {
    my $field = shift;

    my @options;

    for my $item ( @{ $field->form->items_master_list } ) {
        push @options => {
            label => $item->{name},
            value => $item->{name},
        };
    }

    return \@options;
};

sub item_list : Private {
    my ($self, $c) = @_;

    my $max_items = $c->cobrand->bulky_items_maximum;
    my $field_list = [];

    my $notes_field = {
        type => 'TextArea',
        label => 'Item note',
        maxlength => 100,
        tags => { hint => 'Describe the item to help our crew pick up the right thing' },
    };
    if (!$c->cobrand->bulky_item_notes_field_mandatory) {
        $notes_field->{label} .= ' (optional)';
    }

    if ($c->cobrand->moniker eq 'brent') {
        $notes_field = {
            type => 'Text',
            label => 'If other small electrical, please specify',
            maxlength => 100,
        };
    }

    sub item_fields {
        my ($num, $notes_field) = @_;
        return (
            "item_$num" => {
                type => 'Select',
                label => "Item",
                id => "item_$num",
                empty_select => 'Please select an item',
                tags => { autocomplete => 1 },
                options_method => \&bulky_item_options_method,
                messages => { required => 'Please select an item' },
            },
            "item_photo_$num" => {
                type => 'Photo',
                label => 'Upload image (optional)',
                tags => { max_photos => 1 },
                # XXX Limit to JPG etc.
            },
            "item_photo_${num}_fileid" => {
                type => 'FileIdPhoto',
                num_photos_required => 0,
                linked_field => "item_photo_$num",
            },
            "item_notes_${num}" => $notes_field,
        );
    }

    for my $num ( 1 .. $max_items ) {
        if ($c->cobrand->bulky_item_notes_field_mandatory) {
            $notes_field = {
                %$notes_field,
                required_when => { "item_$num" => sub { $_[0] ne "" } },
            };
        }
        push @$field_list, item_fields($num, $notes_field);
    }

    $c->stash->{page_list} = [
        add_items => {
            fields => [ 'continue',
                map { ("item_$_", "item_photo_$_", "item_photo_${_}_fileid", "item_notes_$_") } ( 1 .. $max_items ),
            ],
            template => 'waste/bulky/items.html',
            title => 'Add items for collection',
            next => $c->cobrand->call_hook('bulky_show_location_page') ? 'location' : 'summary',
            update_field_list => sub {
                my $form = shift;
                my $fields = {};
                my $data = $form->saved_data;
                my $c = $form->{c};
                $c->cobrand->bulky_total_cost($data);
                $c->stash->{total} = ($c->stash->{payment} || 0) / 100;
                return $fields;
            },
        },
    ];
    $c->stash->{field_list} = $field_list;

    # Blank page for template
    my $form_class = $c->stash->{form_class};
    my $form = $form_class->new(
        page_list => [ add_items => {
            fields => [ "continue", "item_999", "item_photo_999", "item_photo_999_fileid", "item_notes_999" ],
        } ],
        field_list => [ item_fields(999, $notes_field) ],
        page_name => 'add_items',
        csrf_token => $c->stash->{csrf_token},
        c => $c,
        no_preload => 1,
        unique_id_session => $c->session->{form_unique_id},
        unique_id_form => $c->get_param('unique_id'),
    );
    $form->process;
    $c->stash->{blank_form} = $form;
}

sub index : PathPart('') : Chained('setup') : Args(0) {
    my ($self, $c) = @_;

    my $cfg = $c->cobrand->feature('waste_features');
    if ($c->stash->{pending_bulky_collections} && !$cfg->{bulky_multiple_bookings}) {
        $c->detach('/waste/property_redirect');
    }

    $c->stash->{first_page} = 'intro';
    $c->stash->{form_class} ||= 'FixMyStreet::App::Form::Waste::Bulky';
    $c->stash->{form_class} = 'FixMyStreet::App::Form::Waste::Bulky::Bexley' if $c->cobrand->moniker eq 'bexley';
    $c->forward('item_list');
    $c->forward('form');

    if ( $c->stash->{form}->current_page->name eq 'intro' ) {
        $c->cobrand->call_hook(
            clear_cached_lookups_bulky_slots => $c->stash->{property}{id} );
    }
}

sub index_small : PathPart('') : Chained('setup_small') : Args(0) {
    my ($self, $c) = @_;
    $c->stash->{form_class} = 'FixMyStreet::App::Form::Waste::SmallItems';
    $c->detach('index');
}

sub amend : Chained('setup') : Args(1) {
    my ($self, $c, $id) = @_;

    $c->stash->{first_page} = 'intro';
    $c->stash->{form_class} = 'FixMyStreet::App::Form::Waste::Bulky::Amend';

    my $collection = $c->cobrand->find_pending_bulky_collections($c->stash->{property}{uprn})->find($id);
    $c->detach('/waste/property_redirect')
        if !$c->cobrand->call_hook('bulky_can_amend_collection', $collection);

    $c->stash->{amending_booking} = $collection;

    if ( $c->req->method eq 'GET') { # XXX
        my $saved_data = $c->cobrand->waste_reconstruct_bulky_data($collection);
        my $saved_data_field = FixMyStreet::App::Form::Field::JSON->new(name => 'saved_data');
        $saved_data = $saved_data_field->deflate_json($saved_data);
        $c->set_param(saved_data => $saved_data);
    }

    $c->forward('item_list');
    $c->forward('form');

    if ( $c->stash->{form}->current_page->name eq 'intro' ) {
        $c->cobrand->call_hook(
            clear_cached_lookups_bulky_slots => $c->stash->{property}{id} );
    }
}

# Called by F::A::Controller::Report::display if the report in question is
# a bulky goods collection.
sub view : Private {
    my ($self, $c) = @_;

    my $p = $c->stash->{problem};

    $c->stash->{property} = {
        id => $p->waste_property_id,
        address => $p->get_extra_metadata('property_address'),
    };

    $c->stash->{template} = 'waste/bulky/summary.html';

    $c->forward('/report/load_updates');

    my $saved_data = $c->cobrand->waste_reconstruct_bulky_data($p);
    $c->stash->{form} = {
        items_extra => $c->cobrand->call_hook('bulky_items_extra', exclude_pricing => 1),
        saved_data  => $saved_data,
    };
}

sub cancel : Chained('setup') : Args(1) {
    my ( $self, $c, $id ) = @_;

    $c->detach( '/auth/redirect' ) unless $c->user_exists;

    my $collection = $c->cobrand->find_pending_bulky_collections($c->stash->{property}{uprn})->find($id);
    $c->detach('/waste/property_redirect')
        if !$c->cobrand->call_hook('bulky_can_cancel_collection', $collection);

    $c->stash->{cancelling_booking} = $collection;
    $c->stash->{first_page} = 'intro';
    $c->stash->{form_class} ||= 'FixMyStreet::App::Form::Waste::Bulky::Cancel';
    $c->stash->{entitled_to_refund} = $c->cobrand->call_hook(bulky_can_refund => $collection);
    $c->forward('form');
}

sub cancel_small : PathPart('cancel') : Chained('setup_small') : Args(1) {
    my ( $self, $c, $id ) = @_;
    $c->stash->{form_class} = 'FixMyStreet::App::Form::Waste::SmallItems::Cancel';
    $c->detach('cancel');
}

sub process_bulky_data : Private {
    my ($self, $c, $form) = @_;
    my $data = $form->saved_data;

    my $payment_method = $data->{payment_method} || 'credit_card';
    if (!$c->cobrand->bulky_free_collection_available) {
        # Either was picked in the form, or if not present will be card
        $c->set_param('payment_method', $payment_method);
        if ($payment_method eq 'credit_card' && $c->stash->{staff_payments_allowed} eq 'paye') {
            $c->set_param('payment_method', 'csc');
        }
    }

    $c->cobrand->call_hook("waste_munge_bulky_data", $data);

    # Read extra details in loop
    foreach (grep { /^extra_/ } keys %$data) {
        my ($id) = /^extra_(.*)/;
        $c->set_param($id, $data->{$_});
    }

    $c->stash->{waste_email_type} = 'bulky';
    $c->stash->{override_confirmation_template} = 'waste/bulky/confirmation.html';

    if ($c->stash->{payment}) {
        $c->set_param('payment', $c->stash->{payment});
        if ($data->{continue_id}) {
            $c->stash->{report} = $c->cobrand->problems->find($data->{continue_id});
            amend_extra_data($c, $c->stash->{report}, $data);
            $c->stash->{report}->update;
        } else {
            my $no_confirm = !$c->cobrand->bulky_send_before_payment;
            $c->forward('/waste/add_report', [ $data, $no_confirm ]) or return;
        }

        # Need to record stuff here if we're amending a booking and might be redirected elsewhere...
        if (my $amending = $c->stash->{amending_booking}) {
            my $p = $c->stash->{report};
            $p->set_extra_metadata(previous_booking_id => $amending->id);
            $p->detail($p->detail . " | Previously submitted as " . $amending->external_id);
            $p->update;
        }

        if ( FixMyStreet->staging_flag('skip_waste_payment') ) {
            $c->forward('/waste/pay_skip', []);
        } elsif ($payment_method eq 'cheque') {
            $c->forward('/waste/pay_skip', [ $data->{cheque_reference}, undef ]);
        } elsif ($payment_method eq 'waived') {
            $c->forward('/waste/pay_skip', [ undef, $data->{payment_explanation} ]);
        } else {
            if ( $c->stash->{staff_payments_allowed} eq 'paye' ) {
                $c->forward('/waste/csc_code');
            } else {
                $c->forward('/waste/pay', [ 'bulky' ]);
            }
        }
    } else {
        $c->forward('/waste/add_report', [ $data ]) or return;
    }
    return 1;
}

sub process_bulky_amend : Private {
    my ($self, $c, $form) = @_;
    my $data = $form->saved_data;

    $c->stash->{override_confirmation_template} = 'waste/bulky/confirmation.html';

    my $p = $c->stash->{amending_booking};

    if ($c->cobrand->bulky_cancel_by_update) {
        # In this case we want to update the event to mark it as cancelled,
        # then create a new event with the amended booking data from the form
        my $update = add_cancellation_update($c, $p, 'delayed');

        $c->forward('process_bulky_data', [ $form ]) or return;

        # If there wasn't payment, we reach here and can set the things
        $c->forward('cancel_collection', [ $p, 'amendment' ]);
        my $new = $c->stash->{report};
        $new->set_extra_metadata(previous_booking_id => $p->id);
        foreach (qw(payment_reference chequeReference)) {
            $new->set_extra_metadata($_ => $p->get_extra_metadata($_)) if $p->get_extra_metadata($_);
        }
        $new->detail($new->detail . " | Previously submitted as " . $p->external_id);
        $new->update;
        $update->confirm;
        $update->update;
        $new->bulky_add_payment_confirmation_update($p->get_extra_metadata('payment_reference'));
        if ($c->cobrand->suppress_report_sent_email($new)) {
            $new->send_logged_email({ report => $new, cobrand => $c->cobrand }, 0, $c->cobrand);
        }
    } else {
        $p->create_related( moderation_original_data => {
            title => $p->title,
            detail => $p->detail,
            photo => $p->photo,
            anonymous => $p->anonymous,
            category => $p->category,
            extra => $p->extra,
        });

        $p->detail($p->detail . " | Previously submitted as " . $p->external_id);

        amend_extra_data($c, $p, $data);
        $c->forward('add_cancellation_report');

        $p->resend;
        $p->external_id(undef);
        $p->update;

        # Need to reset stashed report to the amended one, not the new cancellation one
        $c->stash->{report} = $p;
    }

    return 1;
}

sub amend_extra_data {
    my ($c, $p, $data) = @_;

    $c->cobrand->waste_munge_bulky_amend($p, $data);

    if ($data->{location_photo}) {
        $p->set_extra_metadata(location_photo => $data->{location_photo})
    } else {
        $p->unset_extra_metadata('location_photo');
    }

    my $max = $c->cobrand->bulky_items_maximum;
    for (1..$max) {
        if ($data->{"item_photo_$_"}) {
            $p->set_extra_metadata("item_photo_$_" => $data->{"item_photo_$_"})
        } else {
            $p->unset_extra_metadata("item_photo_$_");
        }
    }

    my @bulky_photo_data;
    push @bulky_photo_data, $data->{location_photo} if $data->{location_photo};
    for (grep { /^item_photo_\d+$/ } sort keys %$data) {
        push @bulky_photo_data, $data->{$_} if $data->{$_};
    }
    $p->photo( join(',', @bulky_photo_data) );
}

# bulky_cancel_by_update is false if this is called
sub add_cancellation_report : Private {
    my ($self, $c) = @_;

    my $collection_report = $c->stash->{cancelling_booking} || $c->stash->{amending_booking};
    my %data = (
        detail => $collection_report->detail,
        name   => $collection_report->name,
    );
    $c->cobrand->call_hook( "waste_munge_bulky_cancellation_data", \%data );

    $c->forward( '/waste/add_report', [ \%data ] ) or return;
    if ($c->stash->{amending_booking}) {
        $c->stash->{report}->set_extra_metadata(bulky_amendment_cancel => 1);
        $c->stash->{report}->update;
    }
    return 1;
}

sub add_cancellation_update {
    my ($c, $p, $type) = @_;

    my $description = $c->stash->{non_user_cancel} ? "Booking cancelled" : $type eq 'delayed' ? "Booking cancelled due to amendment" : "Booking cancelled by customer";
    my $update = $p->add_to_comments({
        text => $description,
        user => $c->cobrand->body->comment_user || $p->user,
        extra => { bulky_cancellation => 1 },
        problem_state => 'cancelled',
        $type eq 'immediate' ? (state => 'confirmed') : (state => 'unconfirmed'),
    });
    # We don't want to send an update if amending, they'll get a new report logged email
    $p->cancel_update_alert($update->id) if $type eq 'delayed';
    return $update;
}

sub process_bulky_cancellation : Private {
    my ( $self, $c, $form ) = @_;

    my $collection_report = $c->stash->{cancelling_booking} || $c->stash->{amending_booking};
    if ($c->cobrand->bulky_cancel_by_update) {
        add_cancellation_update($c, $collection_report, 'immediate');
    } else {
        $c->forward('add_cancellation_report') or return;
    }

    $c->forward('cancel_collection', [ $collection_report, 'cancellation' ]);

    $c->cobrand->call_hook('bulky_send_cancellation_confirmation' => $collection_report);

    # Was collection a free one? If so, reset 'FREE BULKY USED' on premises.
    $c->cobrand->call_hook('unset_free_bulky_used');

    if ( $c->cobrand->call_hook(bulky_can_refund => $collection_report) ) {
        $c->cobrand->call_hook(bulky_refund_collection => $collection_report);
        $c->stash->{entitled_to_refund} = 1;
    }

    return 1;
}

# Mark original report as closed
sub cancel_collection : Private {
    my ($self, $c, $report, $type) = @_;
    $report->bulky_cancel_collection($type, $c->stash->{non_user_cancel});
}

__PACKAGE__->meta->make_immutable;

1;
