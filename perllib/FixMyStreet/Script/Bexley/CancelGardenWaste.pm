=head1 NAME

FixMyStreet::Script::Bexley::CancelGardenWaste - cancel garden waste subscriptions from Agile

=cut

package FixMyStreet::Script::Bexley::CancelGardenWaste;

use v5.14;
use warnings;
use Moo;
use Integrations::Agile;
use DateTime;
use FixMyStreet;
use JSON::MaybeXS qw(encode_json);

has 'cobrand' => ( is => 'ro', required => 1 );
has 'verbose' => ( is => 'ro', default => 0 );
has 'agile' => (
    is => 'lazy',
    default => sub {
        my $self = shift;
        my $config = $self->cobrand->feature('agile');
        return Integrations::Agile->new(%$config);
    },
);

sub cancel_from_api {
    my ($self, $days) = @_;

    my $contracts = $self->agile->LastCancelled($days);
    if (ref $contracts eq 'HASH' && $contracts->{error}) {
        warn "Error fetching cancellations: $contracts->{error}\n";
        return;
    }

    unless ($contracts && @$contracts) {
        $self->_vprint("No cancellations found in the last $days days");
        return;
    }
    $self->_vprint("Found " . scalar(@$contracts) . " cancellations");

    foreach my $contract (@$contracts) {
        $self->cancel_contract( $contract );
    }
}

sub cancel_contract {
    my ( $self, $contract ) = @_;

    my $uprn = $contract->{UPRN};
    my $id = $contract->{Id} // "";
    my $reference = $contract->{Reference};
    my $reason = $contract->{Reason};

    $self->_vprint("Attempting to cancel contract $reference (UPRN: $uprn)");

    # Find active garden subscription reports matching this Agile reference.
    # Based on get_original_sub in FixMyStreet/App/Controller/Waste.pm.
    my $report = $self->cobrand->problems->search({
        category => 'Garden Subscription',
        title => ['Garden Subscription - New', 'Garden Subscription - Renew'],
        # New reports get the reference back from Agile, but renewals get the
        # ID, so we need to check for both.
        external_id => [ "Agile-$reference", "Agile-$id" ],
        state => { '!=' => 'hidden' },
        -bool => \"extra->>'direct_debit_cancellation_date' IS NULL",
    })->order_by('-id')->first;

    # Always check for legacy contracts regardless of whether we found a report.
    my $legacy_contract_ids = $self->cobrand->waste_get_legacy_contract_ids($uprn);
    if ($legacy_contract_ids) {
        $self->_cancel_legacy_direct_debit($legacy_contract_ids, $reference);
    }

    unless ($report) {
        # Expected as we might have handled a legacy cancellation above.
        $self->_vprint("  No active garden subscription found for Agile report $id ($reference)");
        return;
    }

    $self->_vprint("  Found active report " . $report->id);

    my $payment_method = $report->get_extra_field_value('payment_method') || 'credit_card';
    if ($payment_method eq 'direct_debit') {
        $self->_cancel_direct_debit($report, $reference);
    } else {
        # Nothing to do for credit card
    }
}

sub _cancel_direct_debit {
    my ($self, $original_report, $reference) = @_;

    my $i = $self->cobrand->get_dd_integration;
    unless ($i) {
        die("Could not get Direct Debit integration object (while processing Agile reference $reference)");
    }

    my $contract_id = $original_report->get_extra_metadata('direct_debit_contract_id');
    unless ($contract_id) {
        print "  WARNING: No contract ID in metadata for Agile reference $reference (report " . $original_report->id . ")\n";
        return;
    }

    $self->_vprint("  Cancelling Direct Debit plan with contract ID $contract_id");

    my $resp = $i->cancel_plan({ dd_reference => $contract_id, report => $original_report });

    if ( ref $resp eq 'HASH' && $resp->{error} ) {
        print "  Failed to send cancellation request to Direct Debit provider for Agile reference $reference: $resp->{error}\n";
    } else {
        $self->_vprint(
            "  Successfully sent cancellation request to Direct Debit provider."
        );
    }
}

sub _cancel_legacy_direct_debit {
    my ($self, $legacy_contract_ids, $reference) = @_;

    my $i = $self->cobrand->get_dd_integration;
    unless ($i) {
        $self->_vprint("  WARNING: Could not get Direct Debit integration object. Unable to cancel legacy contracts.");
        return;
    }

    $self->_vprint("  Found " . scalar(@$legacy_contract_ids) . " legacy contract(s) to try");
    $self->_vprint("  Cancelling Direct Debit plan");

    my $resp = $i->cancel_plan({ contract_ids => $legacy_contract_ids });

    if ( ref $resp eq 'HASH' && $resp->{error} ) {
        print "  Failed to send legacy cancellation request to Direct Debit provider for Agile reference $reference: $resp->{error}\n";
    } else {
        $self->_vprint(
            "  Successfully sent cancellation request to Direct Debit provider."
        );
    }
}

sub _vprint {
    my ($self, $message) = @_;
    print "$message\n" if $self->verbose;
}

1;
