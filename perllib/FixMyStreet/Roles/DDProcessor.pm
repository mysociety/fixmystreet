package FixMyStreet::Roles::DDProcessor;

use Moo::Role;
use strict;
use warnings;

sub log_level {
    my $self = shift;
    return $self->get_config->{debug_level} || 'INFO';
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
    my $self = shift;

    my $today = DateTime->now;
    my $start = $today->clone->add( days => -14 );

    my $i = $self->get_dd_integration();

    my $recent = $i->get_recent_payments({
        start => $start,
        end => $today
    });

    RECORD: for my $payment ( @$recent ) {

        $self->log( "\nlooking at payment " . $payment->{$self->referenceField} );

        my $date = $payment->{$self->paymentDateField};

        $self->log( "payment date: $date" );

        next unless $self->waste_dd_paid($date);

        my ($category, $type) = $self->waste_payment_type(
            $payment->{$self->paymentTypeField},
            $payment->{$self->oneOffReferenceField}
        );

        next unless $category && $date;

        $self->log( "category: $category" );

        my $payer = $payment->{$self->referenceField};

        (my $uprn = $payer) =~ s/^GGW//;

        my $len = length($uprn);
        my $rs = FixMyStreet::DB->resultset('Problem')->search({
            extra => { like => '%uprn,T5:value,I' . $len . ':'. $uprn . '%' },
        },
        {
                order_by => { -desc => 'created' }
        })->to_body( $self->body );

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
        if ( $type && $type eq $self->waste_subscription_types->{Renew} ) {
            next unless $payment->{$self->statusField} eq $self->paymentTakenCode;
            $self->log("is a renewal");
            $rs = $rs->search({ category => 'Garden Subscription' });
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
                my $sub_type = $cur->get_extra_field_value('Subscription_Type');
                if ( $sub_type eq $self->waste_subscription_types->{New} ) {
                    $self->log("is a matching new report") if !$p;
                    $p = $cur if !$p;
                } elsif ( $sub_type eq $self->waste_subscription_types->{Renew} ) {
                    # already processed
                    next RECORD if $cur->get_extra_metadata('dd_date') && $cur->get_extra_metadata('dd_date') eq $date;
                    # if it's a renewal of a DD where the initial setup was as a renewal
                    $self->log("is a matching renewal report") if !$p;
                    $p = $cur if !$p;
                }
            }
            if ( $p ) {
                my $service = $self->waste_get_current_garden_sub( $p->get_extra_field_value('property_id') );
                unless ($service) {
                    warn "no matching service to renew for $payer\n";
                    next;
                }
                my $renew = _duplicate_waste_report($p, 'Garden Subscription', {
                    Subscription_Type => $self->waste_subscription_types->{Renew},
                    #service_id => $self->garden_waste_service_id,
                    uprn => $uprn,
                    #Subscription_Details_Container_Type => $self->garden_waste_container_id,
                    Subscription_Details_Quantity => $self->waste_get_sub_quantity($service),
                    LastPayMethod => $self->bin_payment_types->{direct_debit},
                    PaymentCode => $payer,
                    payment_method => 'direct_debit',
                } );
                $renew->set_extra_metadata('dd_date', $date);
                $renew->confirm;
                $renew->insert;
                $self->log("created new confirmed report: " . $renew->id);
                $handled = 1;
            }
        # this covers new subscriptions and ad-hoc payments, both of which already have
        # a record in the database as they are the result of user action
        } else {
            next unless $payment->{$self->statusField} eq $self->paymentTakenCode;
            $self->log("is a new/ad hoc");
            # we fetch the confirmed ones as well as we explicitly want to check for
            # processed reports so we can warn on those we are missing.
            $rs = $rs->search({ category => 'Garden Subscription' });
            while ( my $cur = $rs->next ) {
                $self->log("looking at potential match " . $cur->id);
                next unless $self->waste_is_dd_payment($cur);
                if ( my $type = $self->_report_matches_payment( $cur, $payment ) ) {
                    $self->log("found matching report " . $cur->id . " with state " . $cur->state);
                    if ( $cur->state eq 'unconfirmed' && !$handled) {
                        if ( $type eq 'New' ) {
                            $self->log("matching report is New " . $cur->id);
                            if ( !$cur->get_extra_metadata('payerReference') ) {
                                $cur->set_extra_metadata('payerReference', $payer);
                            }
                        }
                        $cur->set_extra_metadata('dd_date', $date);
                        $cur->update_extra_field( {
                            name => 'PaymentCode',
                            description => 'PaymentCode',
                            value => $payer,
                        } );
                        $cur->update_extra_field( {
                            name => 'LastPayMethod',
                            description => 'LastPayMethod',
                            value => $self->bin_payment_types->{direct_debit},
                        } );
                        $self->log("confirming matching report " . $cur->id);
                        $cur->confirm;
                        $cur->update;
                        $handled = 1;
                    } elsif ( $cur->state eq 'unconfirmed' ) {
                        $self->log("hiding matching report " . $cur->id);
                        # if we've pulled out more that one record, e.g. because they
                        # failed to make a payment then skip remaining ones.
                        $cur->state('hidden');
                        $cur->update;
                    } elsif ( $cur->get_extra_metadata('dd_date') && $cur->get_extra_metadata('dd_date') eq $date)  {
                        $self->log("skipping matching report " . $cur->id);
                        next RECORD;
                    }
                }
            }
        }

        unless ( $handled ) {
            warn "no matching record found for $category payment with id $payer\n";
        }

        $self->log( "done looking at payment " . $payment->{$self->referenceField} );
    }

    # There's two options with a cancel payment. If the user has cancelled it outside of
    # WasteWorks then we need to find the original sub and generate a new cancel subscription
    # report.
    #
    # If it's been cancelled inside WasteWorks then we'll have an unconfirmed cancel report
    # which we need to confirm.

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

    $self->log("\n\nProcessing Cancelled payments");
    CANCELLED: for my $payment ( @$cancelled ) {

        $self->log("\nlooking at payment " . $payment->{$self->cancelReferenceField});

        my $date = $payment->{$self->cancelledDateField};
        next unless $date;

        my $payer = $payment->{$self->cancelReferenceField};
        (my $uprn = $payer) =~ s/^GGW//;
        my $len = length($uprn);
        my $rs = FixMyStreet::DB->resultset('Problem')->search({
            extra => { like => '%uprn,T5:value,I' . $len . ':'. $uprn . '%' },
        }, {
            order_by => { -desc => 'created' }
        })->to_body( $self->body );

        $rs = $rs->search({ category => 'Cancel Garden Subscription' });
        my $r;
        while ( my $cur = $rs->next ) {
            $self->log("looking at report " . $cur->id);
            if ( $cur->state eq 'unconfirmed' ) {
                $self->log("found matching report " . $cur->id);
                $r = $cur;
            # already processed
            } elsif ( $cur->get_extra_metadata('dd_date') && $cur->get_extra_metadata('dd_date') eq $date) {
                $self->log("skipping report " . $cur->id);
                next CANCELLED;
            }
        }

        if ( $r ) {
            $self->log("processing matched report " . $r->id);
            my $service = $self->waste_get_current_garden_sub( $r->get_extra_field_value('property_id') );
            # if there's not a service then it's fine as it's already been cancelled
            if ( $service ) {
                $r->set_extra_metadata('dd_date', $date);
                $self->log("confirming report");
                $r->confirm;
                $r->update;
            # there's no service but we don't want to be processing the report all the time.
            } else {
                $self->log("hiding report");
                $r->state('hidden');
                $r->update;
            }
        } else {
            # We don't do anything with DD cancellations that don't have
            # associated Cancel reports, so no need to warn on them
            # warn "no matching record found for Cancel payment with id $payer\n";
        }
        $self->log("finished looking at payment " . $payment->{$self->cancelReferenceField});
    }
}

sub _report_matches_payment {
    my ($self, $r, $p) = @_;

    my $match = 0;
    if ( $p->{$self->oneOffReferenceField} && $r->id eq $p->{$self->oneOffReferenceField} ) {
        $match = 'Ad-Hoc';
    } elsif ( !$p->{$self->oneOffReferenceField}
            && ( $r->get_extra_field_value('Subscription_Type') eq $self->waste_subscription_types->{New} ||
                 # if we're renewing a previously non DD sub
                 $r->get_extra_field_value('Subscription_Type') eq $self->waste_subscription_types->{Renew} )
    ) {
        $match = 'New';
    }

    return $match;
}

sub _duplicate_waste_report {
    my ( $report, $category, $extra ) = @_;
    my $new = FixMyStreet::DB->resultset('Problem')->new({
        category => $category,
        user => $report->user,
        latitude => $report->latitude,
        longitude => $report->longitude,
        cobrand => $report->cobrand,
        bodies_str => $report->bodies_str,
        title => $report->title,
        detail => $report->detail,
        postcode => $report->postcode,
        used_map => $report->used_map,
        name => $report->user->name || $report->name,
        areas => $report->areas,
        anonymous => $report->anonymous,
        state => 'unconfirmed',
        non_public => 1,
    });

    $extra->{Subscription_Details_Container_Type} ||= $report->get_extra_field_value('Subscription_Details_Container_Type');
    $extra->{service_id} ||= $report->get_extra_field_value('service_id');

    my @extra = map { { name => $_, value => $extra->{$_} } } keys %$extra;
    $new->set_extra_fields(@extra);

    return $new;
}

sub waste_get_current_garden_sub {
    my ( $self, $id ) = @_;

    my $echo = $self->feature('echo');
    $echo = Integrations::Echo->new(%$echo);
    my $services = $echo->GetServiceUnitsForObject( $id );
    return undef unless $services;

    my $garden;
    for my $service ( @$services ) {
        if ( $service->{ServiceId} == $self->garden_service_id ) {
            $garden = $self->_get_current_service_task($service);
            last;
        }
    }

    return $garden;
}

sub waste_get_sub_quantity {
    my ($self, $service) = @_;

    my $quantity = 0;
    my $tasks = Integrations::Echo::force_arrayref($service->{Data}, 'ExtensibleDatum');
    return 0 unless scalar @$tasks;
    for my $data ( @$tasks ) {
        next unless $data->{DatatypeName} eq 'LBB - GW Container';
        next unless $data->{ChildData};
        my $kids = $data->{ChildData}->{ExtensibleDatum};
        $kids = [ $kids ] if ref $kids eq 'HASH';
        for my $child ( @$kids ) {
            next unless $child->{DatatypeName} eq 'Quantity';
            $quantity = $child->{Value}
        }
    }

    return $quantity;
}

sub log {
    my ($self, $message, $level) = @_;

    $level ||= 'DEBUG';

    print $message . "\n" if
        $self->logging_levels->{$level} >= $self->logging_levels->{$self->log_level};
}

1;
