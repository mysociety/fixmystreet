package FixMyStreet::App::Controller::Waste::Bulky;
use Moose;
use namespace::autoclean;

BEGIN { extends 'FixMyStreet::App::Controller::Form' }

use utf8;
use FixMyStreet::App::Form::Waste::Bulky;
use FixMyStreet::App::Form::Waste::Bulky::Amend;
use FixMyStreet::App::Form::Waste::Bulky::Cancel;

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

    for my $num ( 1 .. $max_items ) {
        push @$field_list,
            "item_$num" => {
                type => 'Select',
                label => "Item $num",
                id => "item_$num",
                empty_select => 'Please select an item',
                tags => { autocomplete => 1 },
                options_method => \&bulky_item_options_method,
                $num == 1 ? (required => 1) : (),
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
            "item_notes_${num}" => {
                type => 'TextArea',
                label => 'Item note (optional)',
                maxlength => 100,
                tags => { hint => 'Describe the item to help our crew pick up the right thing' },
            };
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
                $c->stash->{total} = $c->stash->{payment} / 100;
                for my $num ( 1 .. $max_items ) {
                    $form->update_photo("item_photo_$num", $fields);
                }
                return $fields;
            },
        },
    ];
    $c->stash->{field_list} = $field_list;
}

sub index : PathPart('') : Chained('setup') : Args(0) {
    my ($self, $c) = @_;

    my $cfg = $c->cobrand->feature('waste_features');
    if ($c->stash->{pending_bulky_collections} && !$cfg->{bulky_multiple_bookings}) {
        $c->detach('/waste/property_redirect');
    }

    $c->stash->{first_page} = 'intro';
    $c->stash->{form_class} = 'FixMyStreet::App::Form::Waste::Bulky';
    $c->forward('item_list');
    $c->forward('form');

    if ( $c->stash->{form}->current_page->name eq 'intro' ) {
        $c->cobrand->call_hook(
            clear_cached_lookups_bulky_slots => $c->stash->{property}{id} );
    }
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
        id => $p->get_extra_field_value('property_id'),
        address => $p->get_extra_metadata('property_address'),
    };

    $c->stash->{template} = 'waste/bulky/summary.html';

    $c->forward('/report/load_updates');

    my $saved_data = $c->cobrand->waste_reconstruct_bulky_data($p);
    $c->stash->{form} = {
        items_extra => $c->cobrand->call_hook('bulky_items_extra'),
        saved_data  => $saved_data,
    };
}

sub cancel : Chained('setup') : Args(1) {
    my ( $self, $c, $id ) = @_;

    $c->detach( '/auth/redirect' ) unless $c->user_exists;

    my $collection = $c->cobrand->find_pending_bulky_collections($c->stash->{property}{uprn})->find($id);
    $c->detach('/waste/property_redirect')
        if !$c->cobrand->call_hook('bulky_can_view_collection', $collection)
            || !$c->cobrand->call_hook('bulky_collection_can_be_cancelled', $collection);

    $c->stash->{cancelling_booking} = $collection;
    $c->stash->{first_page} = 'intro';
    $c->stash->{form_class} = 'FixMyStreet::App::Form::Waste::Bulky::Cancel';
    $c->stash->{entitled_to_refund} = $c->cobrand->call_hook(bulky_can_refund => $collection);
    $c->forward('form');
}

sub process_bulky_data : Private {
    my ($self, $c, $form) = @_;
    my $data = $form->saved_data;

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
        if ( FixMyStreet->staging_flag('skip_waste_payment') ) {
            $c->stash->{message} = 'Payment skipped on staging';
            $c->stash->{reference} = $c->stash->{report}->id;
            $c->forward('/waste/confirm_subscription', [ $c->stash->{reference} ] );
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

    if ($c->cobrand->bulky_cancel_by_update) {
        # TODO In this case we would want to update the event; we can't both
        # cancel the booking by update and also resend it as a new booking
        # (which works okay when a new cancellation event is being created)
        die "Not currently functional";
    }

    $c->forward('add_cancellation_report');

    $p->resend;
    $p->external_id(undef);
    $p->update;

    # Need to reset stashed report to the amended one, not the new cancellation one
    $c->stash->{report} = $p;

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

sub add_cancellation_report : Private {
    my ($self, $c) = @_;

    my $collection_report = $c->stash->{cancelling_booking} || $c->stash->{amending_booking};
    my %data = (
        detail => $collection_report->detail,
        name   => $collection_report->name,
    );
    $c->cobrand->call_hook( "waste_munge_bulky_cancellation_data", \%data );

    if ($c->cobrand->bulky_cancel_by_update) {
        $collection_report->add_to_comments({
            text => 'Booking cancelled by customer',
            user => $c->cobrand->body->comment_user || $collection_report->user,
            extra => { bulky_cancellation => 1 },
        });
    } else {
        $c->forward( '/waste/add_report', [ \%data ] ) or return;
        if ($c->stash->{amending_booking}) {
            $c->stash->{report}->set_extra_metadata(bulky_amendment_cancel => 1);
            $c->stash->{report}->update;
        }
    }
    return 1;
}

sub process_bulky_cancellation : Private {
    my ( $self, $c, $form ) = @_;

    $c->forward('add_cancellation_report') or return;
    my $collection_report = $c->stash->{cancelling_booking} || $c->stash->{amending_booking};

    # Mark original report as closed
    $collection_report->state('closed');
    $collection_report->detail(
        $collection_report->detail . " | Cancelled at user request", );
    $collection_report->update;

    # Was collection a free one? If so, reset 'FREE BULKY USED' on premises.
    $c->cobrand->call_hook('unset_free_bulky_used');

    if ( $c->cobrand->call_hook(bulky_can_refund => $collection_report) ) {
        $c->send_email(
            'waste/bulky-refund-request.txt',
            {   to => [
                    [ $c->cobrand->contact_email, $c->cobrand->council_name ]
                ],

                payment_method =>
                    $collection_report->get_extra_field_value('payment_method'),
                payment_code =>
                    $collection_report->get_extra_field_value('PaymentCode'),
                auth_code =>
                    $collection_report->get_extra_metadata('authCode'),
                continuous_audit_number =>
                    $collection_report->get_extra_metadata(
                    'continuousAuditNumber'),
                original_sr_number => $c->get_param('ORIGINAL_SR_NUMBER'),
                payment_date       => $collection_report->created,
                scp_response       =>
                    $collection_report->get_extra_metadata('scpReference'),
            },
        );

        $c->stash->{entitled_to_refund} = 1;
    }

    return 1;
}

__PACKAGE__->meta->make_immutable;

1;
