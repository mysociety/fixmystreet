package FixMyStreet::Roles::CobrandPay360;

use Moo::Role;
use strict;
use warnings;
use Integrations::Echo;
use Integrations::Pay360;

sub waste_payment_type {
    my ($self, $type, $ref) = @_;

    my ($sub_type, $category);
    if ( $type eq 'Payment: 01' || $type eq 'First Time' ) {
        $category = 'Garden Subscription';
        $sub_type = $self->waste_subscription_types->{New};
    } elsif ( $type eq 'Payment: 17' || $type eq 'Regular' ) {
        $category = 'Garden Subscription';
        if ( $ref ) {
            $sub_type = $self->waste_subscription_types->{Amend};
        } else {
            $sub_type = $self->waste_subscription_types->{Renew};
        }
    }

    return ($category, $sub_type);
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

    my $config = $self->feature('payment_gateway');
    my $i = Integrations::Pay360->new({
        config => $config
    });

    my $recent = $i->get_recent_payments({
        start => $start,
        end => $today
    });

    RECORD: for my $payment ( @$recent ) {

        my $date = $payment->{DueDate};
        next unless $self->waste_dd_paid($date);

        my ($category, $type) = $self->waste_payment_type ( $payment->{Type}, $payment->{YourRef} );

        next unless $category && $date;

        my $payer = $payment->{PayerReference};

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
            next unless $payment->{Status} eq 'Paid';
            $rs = $rs->search({ category => 'Garden Subscription' });
            my $p;
            # loop over all matching records and pick the most recent new sub or renewal
            # record. This is where we get the details of the renewal from. There should
            # always be one of these for an automatic DD renewal. If there isn't then
            # something has gone wrong and we need to error.
            while ( my $cur = $rs->next ) {
                # only match direct debit payments
                next unless $self->waste_is_dd_payment($cur);
                # only confirmed records are valid.
                next unless FixMyStreet::DB::Result::Problem->visible_states()->{$cur->state};
                my $sub_type = $cur->get_extra_field_value('Subscription_Type');
                if ( $sub_type eq $self->waste_subscription_types->{New} ) {
                    $p = $cur if !$p;
                } elsif ( $sub_type eq $self->waste_subscription_types->{Renew} ) {
                    # already processed
                    next RECORD if $cur->get_extra_metadata('dd_date') && $cur->get_extra_metadata('dd_date') eq $date;
                    # if it's a renewal of a DD where the initial setup was as a renewal
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
                    service_id => 545,
                    uprn => $uprn,
                    Subscription_Details_Container_Type => 44,
                    Subscription_Details_Quantity => $self->waste_get_sub_quantity($service),
                    LastPayMethod => $self->bin_payment_types->{direct_debit},
                    PaymentCode => $payer,
                    payment_method => 'direct_debit',
                } );
                $renew->set_extra_metadata('dd_date', $date);
                $renew->confirm;
                $renew->insert;
                $handled = 1;
            }
        # this covers new subscriptions and ad-hoc payments, both of which already have
        # a record in the database as they are the result of user action
        } else {
            next unless $payment->{Status} eq 'Paid';
            # we fetch the confirmed ones as well as we explicitly want to check for
            # processed reports so we can warn on those we are missing.
            $rs = $rs->search({ category => 'Garden Subscription' });
            while ( my $cur = $rs->next ) {
                next unless $self->waste_is_dd_payment($cur);
                if ( my $type = $self->_report_matches_payment( $cur, $payment ) ) {
                    if ( $cur->state eq 'unconfirmed' && !$handled) {
                        if ( $type eq 'New' ) {
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
                        $cur->confirm;
                        $cur->update;
                        $handled = 1;
                    } elsif ( $cur->state eq 'unconfirmed' ) {
                        # if we've pulled out more that one record, e.g. because they
                        # failed to make a payment then skip remaining ones.
                        $cur->state('hidden');
                        $cur->update;
                    } elsif ( $cur->get_extra_metadata('dd_date') && $cur->get_extra_metadata('dd_date') eq $date)  {
                        next RECORD;
                    }
                }
            }
        }

        unless ( $handled ) {
            warn "no matching record found for $category payment with id $payer\n";
        }
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

    CANCELLED: for my $payment ( @$cancelled ) {

        my $date = $payment->{CancelledDate};
        next unless $date;

        my $payer = $payment->{Reference};
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
            if ( $cur->state eq 'unconfirmed' ) {
                $r = $cur;
            # already processed
            } elsif ( $cur->get_extra_metadata('dd_date') && $cur->get_extra_metadata('dd_date') eq $date) {
                next CANCELLED;
            }
        }

        if ( $r ) {
            my $service = $self->waste_get_current_garden_sub( $r->get_extra_field_value('property_id') );
            # if there's not a service then it's fine as it's already been cancelled
            if ( $service ) {
                $r->set_extra_metadata('dd_date', $date);
                $r->confirm;
                $r->update;
            # there's no service but we don't want to be processing the report all the time.
            } else {
                $r->state('hidden');
                $r->update;
            }
        } else {
            # We don't do anything with DD cancellations that don't have
            # associated Cancel reports, so no need to warn on them
            # warn "no matching record found for Cancel payment with id $payer\n";
        }
    }
}

sub _report_matches_payment {
    my ($self, $r, $p) = @_;

    my $match = 0;
    if ( $p->{YourRef} && $r->id eq $p->{YourRef} ) {
        $match = 'Ad-Hoc';
    } elsif ( !$p->{YourRef}
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

1;
