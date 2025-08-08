package DDPayment;
use Moo;

has data => ( is => 'ro' );
has cobrand => ( is => 'ro' );
has payer => ( is => 'lazy', default => sub { $_[0]->data->{$_[0]->cobrand->referenceField} } );
has date => ( is => 'lazy', default => sub { $_[0]->data->{$_[0]->cobrand->paymentDateField} } );
has status => ( is => 'lazy', default => sub { $_[0]->data->{$_[0]->cobrand->statusField} } );
has type => ( is => 'lazy', default => sub { $_[0]->data->{$_[0]->cobrand->paymentTypeField} } );
has oneOffRef => ( is => 'lazy', default => sub { $_[0]->data->{$_[0]->cobrand->oneOffReferenceField} } );
has amount => ( is => 'lazy', default => sub { $_[0]->data->{Amount} } );

package DDCancelPayment;
use Moo;

has data => ( is => 'ro' );
has cobrand => ( is => 'ro' );
has payer => ( is => 'lazy', default => sub { $_[0]->data->{$_[0]->cobrand->cancelReferenceField} } );
has date => ( is => 'lazy', default => sub { $_[0]->data->{$_[0]->cobrand->cancelledDateField} } );

package FixMyStreet::Roles::Cobrand::DDProcessor;

use utf8;
use Moo::Role;
use Utils;
use JSON::MaybeXS;
use strict;
use warnings;

my $log_level;

sub log_level {
    my $self = shift;
    my $new = shift;
    return $log_level || $self->get_config->{debug_level} || 'INFO';
}

sub logging_levels {
    return {
        WARN => 5,
        INFO => 4,
        DEBUG => 3,
        VERBOSE => 2
    };
}

sub waste_is_dd_payment {
    my ($self, $row) = @_;

    return $row->get_extra_field_value('payment_method') && $row->get_extra_field_value('payment_method') eq 'direct_debit';
}

sub waste_dd_paid {
    my ($self, $date) = @_;

    my ($day, $month, $year) = ( $date =~ m#^(\d+)/(\d+)/(\d+)$#);
    my $dt = DateTime->new(day => $day, month => $month, year => $year);
    return $self->within_working_days($dt, 3, 1);
}

sub waste_reconcile_direct_debits {
    my ($self, $params) = @_;

    my $user = $self->body->comment_user;

    $log_level = "DEBUG" if $params->{verbose};
    my $dry_run = $params->{dry_run};

    warn "running in dry_run mode, no records will be created or updated\n" if $dry_run;

    my $today = DateTime->now;
    my $start = $today->clone->add( days => -14 );

    my $i = $self->get_dd_integration();

    my $recent = $i->get_recent_payments({
        start => $start,
        end => $today
    });

    RECORD: for my $payment ( @$recent ) {
        $self->clear_log;

        $payment = DDPayment->new({ data => $payment, cobrand => $self });
        next unless $payment->date;

        # If there's a `reference` key in $params then we only want to look at
        # payments that match that reference.
        next if $params->{reference} && $payment->payer ne $params->{reference};

        $self->log( "looking at payment " . $payment->payer . " for £" . $payment->amount . " on " . $payment->date );

        next unless $self->waste_dd_paid($payment->date);
        next unless $payment->status eq $self->paymentTakenCode;

        my ($category, $type) = $self->waste_payment_type($payment->type, $payment->oneOffRef);
        next unless $category;

        $self->log( "category: $category ($type)" );

        if ($params->{reference}) {
            if ($params->{force_renewal}) {
                $self->log( "Overriding type $type to renew" );
                $type = $self->waste_subscription_types->{Renew};
            } elsif ($params->{force_new}) {
                $self->log( "Overriding type $type to new" );
                $type = $self->waste_subscription_types->{New};
            }
        }

        my ($uprn, $rs) = $self->_process_reference($payment->payer);
        next unless $rs;
        $rs = $rs->search({ category => 'Garden Subscription' });

        my $handled;

        # Work out what to do with the payment.
        # Processed payments are indicated by a matching record with a dd_date the
        # same as the CollectionDate of the payment
        #
        # Renewal is an automatic event so there is never a record in the database
        # and we have to generate one.
        #
        # If we're a renew payment then find the initial subscription payment, also
        # checking if we've already processed this payment. If we've not processed it
        # create a renewal record using the original subscription as a basis.
        if ( $type eq $self->waste_subscription_types->{Renew} ) {
            $self->log("is a renewal");
            my $p;
            # loop over all matching records and pick the most recent new sub or renewal
            # record. This is where we get the details of the renewal from. There should
            # always be one of these for an automatic DD renewal. If there isn't then
            # something has gone wrong and we need to error.
            while ( my $cur = $rs->next ) {
                $self->log("looking at potential match " . $cur->id . " with state " . $cur->state);
                # only match direct debit payments
                next unless $self->waste_is_dd_payment($cur);
                # only confirmed records are valid.
                next unless FixMyStreet::DB::Result::Problem->visible_states()->{$cur->state};
                # already processed
                next RECORD if $cur->get_extra_metadata('dd_date') && $cur->get_extra_metadata('dd_date') eq $payment->date;
                next if $p;

                my $sub_type = $cur->get_extra_field_value($self->garden_subscription_type_field);
                next unless $sub_type eq $self->waste_subscription_types->{New} || $sub_type eq $self->waste_subscription_types->{Renew};

                if ( $sub_type eq $self->waste_subscription_types->{New} ) {
                    $self->log("is a matching new report");
                } elsif ( $sub_type eq $self->waste_subscription_types->{Renew} ) {
                    $self->log("is a matching renewal report");
                }
                $p = $cur;
            }
            if ( $p ) {
                my $service = $self->waste_get_current_garden_sub( $p->waste_property_id );
                my $quantity;
                if ($service) {
                    $quantity = $self->waste_get_sub_quantity($service);
                } elsif ($params->{reference} && $params->{force_when_missing}) {
                    $quantity = $params->{force_when_missing};
                } else {
                    $self->log("no matching service to renew for " . $payment->payer);
                    $self->output_log(1);
                    next;
                }
                my $renew = $self->_duplicate_waste_report($p, $uprn, $quantity, $payment, $dry_run);
                $handled = $dry_run ? 1 : $renew->id;
            }
        # this covers new subscriptions and ad-hoc payments, both of which already have
        # a record in the database as they are the result of user action
        } else {
            $self->log("is a new/ad hoc");
            # we fetch the confirmed ones as well as we explicitly want to check for
            # processed reports so we can warn on those we are missing.
            while ( my $cur = $rs->next ) {
                $self->log("looking at potential match " . $cur->id);
                next unless $self->waste_is_dd_payment($cur);
                $self->log("potential match is a dd payment");
                my $type = $self->_report_matches_payment( $cur, $payment );
                next unless $type;

                $self->log("found matching report " . $cur->id . " with state " . $cur->state);
                if ( $cur->state eq 'unconfirmed' && !$handled) {
                    $self->_confirm_dd_report($type, $cur, $payment, $dry_run);
                    $handled = $cur->id;
                } elsif ( $cur->state eq 'unconfirmed' ) {
                    # if we've pulled out more that one record, e.g. because they failed to make a payment then skip remaining ones.
                    $self->_hide_matching_dd_report($cur, $handled, $user, $dry_run);
                } elsif ( $cur->get_extra_metadata('dd_date') && $cur->get_extra_metadata('dd_date') eq $payment->date)  {
                    $self->log("skipping matching report " . $cur->id);
                    next RECORD;
                }
            }
        }

        unless ( $handled ) {
            $self->log("no matching record found for $category payment with id " . $payment->payer);
        }

        $self->log( "done looking at payment " . $payment->payer );
        $self->output_log(!$handled);
    }

    # There's two options with a cancel payment. If the user has cancelled it outside
    # of WasteWorks then we do nothing. If it's been cancelled inside WasteWorks then
    # we'll have an unconfirmed cancel report which we need to confirm.

    my $cancelled = $i->get_cancelled_payers({
        start => $start,
        end => $today
    });

    if ( ref $cancelled eq 'HASH' && $cancelled->{error} ) {
        if ( $cancelled->{error} ne 'No cancelled payers found.' ) {
            warn $cancelled->{error} . "\n";
        }
        return;
    }

    $self->clear_log;
    $self->log("Processing Cancelled payments");
    $self->output_log;
    CANCELLED: for my $payment ( @$cancelled ) {
        $self->clear_log;

        $payment = DDCancelPayment->new({ data => $payment, cobrand => $self });
        next unless $payment->date;

        next if $params->{reference} && $payment->payer ne $params->{reference};

        $self->log("looking at payment " . $payment->payer);

        my ($uprn, $rs) = $self->_process_reference($payment->payer);
        next unless $rs;

        $rs = $rs->search({ category => 'Cancel Garden Subscription' });
        my $r;
        while ( my $cur = $rs->next ) {
            $self->log("looking at report " . $cur->id);
            if ( $cur->state eq 'unconfirmed' ) {
                $self->log("found matching report " . $cur->id);
                $r = $cur;
            # already processed
            } elsif ( $cur->get_extra_metadata('dd_date') && $cur->get_extra_metadata('dd_date') eq $payment->date) {
                $self->log("skipping report " . $cur->id);
                next CANCELLED;
            }
        }

        if ( $r ) {
            $self->log("processing matched report " . $r->id);
            my $service = $self->waste_get_current_garden_sub( $r->waste_property_id );
            # if there's not a service then it's fine as it's already been cancelled
            if ( $service ) {
                $r->set_extra_metadata('dd_date', $payment->date);
                $self->log("confirming report");
                $r->confirm;
                $r->update unless $dry_run;
            # there's no service but we don't want to be processing the report all the time.
            } else {
                $self->log("hiding report");
                $r->state('hidden');
                $r->add_to_comments( { text => 'Hiding report as no existing service', user => $user, problem_state => $r->state } ) unless $dry_run;
                $r->update unless $dry_run;
            }
        } else {
            # We don't do anything with DD cancellations that don't have
            # associated Cancel reports, so no need to warn on them
            # warn "no matching record found for Cancel payment with id $payer\n";
        }
        $self->log("finished looking at payment " . $payment->payer);
        $self->output_log;
    }
}

sub add_new_sub_metadata { return; }

sub _report_matches_payment {
    my ($self, $r, $p) = @_;

    my $match = 0;
    $self->log( "one off reference field is " . $p->oneOffRef ) if $p->oneOffRef;
    $self->log( "potential match type is " . $r->get_extra_field_value($self->garden_subscription_type_field) );
    if ( $p->oneOffRef && $r->id eq $p->oneOffRef ) {
        $match = 'Ad-Hoc';
    } elsif ( !$p->oneOffRef
            && ( $r->get_extra_field_value($self->garden_subscription_type_field) eq $self->waste_subscription_types->{New} ||
                 # if we're renewing a previously non DD sub
                 $r->get_extra_field_value($self->garden_subscription_type_field) eq $self->waste_subscription_types->{Renew} )
    ) {
        $match = 'New';
    }

    return $match;
}

sub _duplicate_waste_report {
    my ($self, $report, $uprn, $quantity, $payment, $dry_run) = @_;

    my $extra = {
        $self->garden_subscription_type_field => $self->waste_subscription_types->{Renew},
        uprn => $uprn,
        Subscription_Details_Quantity => $quantity,
        PaymentCode => $payment->payer,
        payment_method => 'direct_debit',
        $self->garden_subscription_container_field => $report->get_extra_field_value($self->garden_subscription_container_field),
        service_id => $report->get_extra_field_value('service_id'),
        property_id => $report->waste_property_id,
    };
    $extra->{LastPayMethod} = $self->bin_payment_types->{direct_debit} if $report->cobrand eq 'bromley';

    # Refetch containing areas as it's possible they've changed since this
    # subscription was initially created.
    my ($lat, $lon) = map { Utils::truncate_coordinate($_) } $report->latitude, $report->longitude;
    my $areas = FixMyStreet::MapIt::call('point', "4326/" . $lon . "," . $lat);

    my $renew = FixMyStreet::DB->resultset('Problem')->new({
        category => 'Garden Subscription',
        user => $report->user,
        latitude => $report->latitude,
        longitude => $report->longitude,
        cobrand => $report->cobrand,
        bodies_str => $report->bodies_str,
        title => 'Garden Subscription - Renew',
        detail => $report->detail,
        postcode => $report->postcode,
        used_map => $report->used_map,
        name => $report->user->name || $report->name,
        areas => ',' . join( ',', sort keys %$areas ) . ',',
        anonymous => $report->anonymous,
        state => 'unconfirmed',
        non_public => 1,
        cobrand_data => 'waste',
        send_questionnaire => 0,
    });

    my @extra = map { { name => $_, value => $extra->{$_} } } keys %$extra;
    $renew->set_extra_fields(@extra);
    $renew->set_extra_metadata('payerReference', $payment->payer);
    $renew->set_extra_metadata('dd_date', $payment->date);
    $renew->confirm;
    $renew->insert unless $dry_run;
    $self->log("created new confirmed report: " . $renew->id) unless $dry_run;

    unless ($dry_run) {
        # Mark user as active as they're renewing their DD
        $renew->user->set_last_active;
        $renew->user->update;
    }

    return $renew;
}

sub _confirm_dd_report {
    my ($self, $type, $cur, $payment, $dry_run) = @_;

    if ( $type eq 'New' ) {
        $self->log("matching report is New " . $cur->id);
        if ( !$cur->get_extra_metadata('payerReference') ) {
            $cur->set_extra_metadata('payerReference', $payment->payer);
        }
    }
    $cur->set_extra_metadata('dd_date', $payment->date);
    $cur->update_extra_field( {
        name => 'PaymentCode',
        description => 'PaymentCode',
        value => $payment->payer,
    } );
    if ($cur->cobrand eq 'bromley') {
        $cur->update_extra_field( {
            name => 'LastPayMethod',
            description => 'LastPayMethod',
            value => $self->bin_payment_types->{direct_debit},
        } );
    }
    $self->add_new_sub_metadata($cur, $payment);
    $cur->confirm;
    $cur->update unless $dry_run;
    $self->log("confirming matching report " . $cur->id);
}

sub _hide_matching_dd_report {
    my ($self, $cur, $handled, $user, $dry_run) = @_;

    $self->log("hiding matching report $handled");
    $cur->state('hidden');
    $cur->add_to_comments( { text => "Hiding report as handled elsewhere by report $handled", user => $user, problem_state => $cur->state } ) unless $dry_run;
    $cur->update unless $dry_run;
}

sub _process_reference {
    my ($self, $payer) = @_;

    # Old style GGW references
    if ((my $uprn = $payer) =~ s/^GGW//) {
        my $rs = FixMyStreet::DB->resultset('Problem')->search({
            extra => { '@>' => encode_json({ payerReference => $payer }) },
        }, {
            order_by => [ { -desc => 'created' }, { -desc => 'id' } ],
        })->to_body( $self->body );
        return ($uprn, $rs);
    }

    my ($id, $uprn) = $payer =~ /^@{[$self->waste_payment_ref_council_code()]}-(\d+)-(\d+)/;

    return (undef, undef) unless $id;
    my $origin = FixMyStreet::DB->resultset('Problem')->find($id);

    if ( !$origin ) {
        $self->log("no matching origin sub for id $id");
        return (undef, undef);
    }

    $uprn = $origin->get_extra_field_value('uprn');
    $self->log( "extra query is {payerReference: $payer" );
    my $rs = FixMyStreet::DB->resultset('Problem')->search({
        -or => [
            id => $id,
            extra => { '@>' => encode_json({ payerReference => $payer }) },
        ]
    })->order_by('-created')->to_body( $self->body );

    return ($uprn, $rs);
}

sub waste_get_current_garden_sub {
    my ( $self, $id ) = @_;

    my $echo = $self->feature('echo');
    $echo = Integrations::Echo->new(%$echo);
    my $services = $echo->GetServiceUnitsForObject( $id );
    return undef unless $services;

    return $self->garden_current_service_from_service_units($services);
}

sub waste_get_sub_quantity {
    my ($self, $service) = @_;

    my $quantity = 0;
    my $tasks = Integrations::Echo::force_arrayref($service->{Data}, 'ExtensibleDatum');
    return 0 unless scalar @$tasks;
    for my $data ( @$tasks ) {
        next unless $data->{DatatypeName} eq $self->garden_echo_container_name;
        my $kids = Integrations::Echo::force_arrayref($data->{ChildData}, 'ExtensibleDatum');
        for my $child ( @$kids ) {
            next unless $child->{DatatypeName} eq 'Quantity';
            $quantity = $child->{Value}
        }
    }

    return $quantity;
}

my @current_log;

sub log {
    my ($self, $message, $level) = @_;
    $level ||= 'DEBUG';
    push @current_log, [ $message, $level ];
}

sub output_log {
    my ($self, $warn) = @_;

    foreach (@current_log) {
        my ($message, $level) = @$_;
        print "$message\n" if
            $self->logging_levels->{$level} >= $self->logging_levels->{$self->log_level};
        warn "$message\n" if $warn;
    }
}

sub clear_log {
    @current_log = (["", "DEBUG"]);
}

1;
