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
        $self->cancel_by_uprn($contract->{UPRN});
    }
}

sub cancel_by_uprn {
    my ($self, $uprn) = @_;

    $self->_vprint("Attempting to cancel subscription for UPRN $uprn");

    # Find active garden subscription report for this UPRN
    my $report = $self->cobrand->problems->search({
        category => 'Garden Subscription',
        extra => { '@>' => encode_json({ "_fields" => [ { name => "uprn", value => $uprn } ] }) },
        state => [ FixMyStreet::DB::Result::Problem->open_states ],
    })->order_by('-id')->first;

    unless ($report) {
        $self->_vprint("  No active garden subscription found for UPRN $uprn");
        return;
    }

    $self->_vprint("  Found active report " . $report->id);

    # TODO: Create a cancellation report (but mark as sent, as it doesn't need to go to Agile)
    # TODO: Check for an existing cancellation for this report before cancelling DD.

    my $payment_method = $report->get_extra_field_value('payment_method') || 'credit_card';
    if ($payment_method eq 'direct_debit') {
        $self->_cancel_direct_debit($report);
    } else {
        # Nothing to do for credit card
    }
}

sub _cancel_direct_debit {
    my ($self, $original_report) = @_;

    my $i = $self->cobrand->get_dd_integration;
    unless ($i) {
        $self->_vprint("  WARNING: Could not get Direct Debit integration object. Unable to cancel at source.");
        return;
    }

    my $payer_ref = $original_report->get_extra_metadata('direct_debit_contract_id');
    if (!$payer_ref) {
        $self->_vprint("  WARNING: Direct debit cancellation failed: direct_debit_contract_id not found on original report " . $original_report->id);
        return;
    }

    $self->_vprint("  Cancelling Direct Debit plan with payer reference $payer_ref");
    my $update_ref = $i->cancel_plan({
        report => $original_report,
    });

    if ($update_ref) {
        $self->_vprint("  Successfully sent cancellation request to Direct Debit provider.");
    } else {
        $self->_vprint("  Failed to send cancellation request to Direct Debit provider.");
    }
}

sub _vprint {
    my ($self, $message) = @_;
    print "$message\n" if $self->verbose;
}

1;
