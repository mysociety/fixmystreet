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
        $self->cancel_by_uprn( $contract->{UPRN}, $contract->{Reason} );
    }
}

sub cancel_by_uprn {
    my ( $self, $uprn, $reason ) = @_;

    $self->_vprint("Attempting to cancel subscription for UPRN $uprn");

    # Find active garden subscription report for this UPRN.
    # Based on get_original_sub in FixMyStreet/App/Controller/Waste.pm.
    my $report = $self->cobrand->problems->search({
        category => 'Garden Subscription',
        title => ['Garden Subscription - New', 'Garden Subscription - Renew'],
        extra => { '@>' => encode_json({ "_fields" => [ { name => "uprn", value => $uprn } ] }) },
        state => { '!=' => 'hidden' },
    })->order_by('-id')->first;

    unless ($report) {
        $self->_vprint("  No active garden subscription found for UPRN $uprn");
        return;
    }

    $self->_vprint("  Found active report " . $report->id);

    # See if there is an existing cancellation report for current subscription
    my $dtf = FixMyStreet::DB->schema->storage->datetime_parser;
    my $current_created = $dtf->format_datetime( $report->created );
    my $cancellation_report = $self->cobrand->problems->search({
        category => 'Cancel Garden Subscription',
        extra => { '@>' => encode_json({ "_fields" => [ { name => "uprn", value => $uprn } ] }) },
        state => [ FixMyStreet::DB::Result::Problem->open_states ],
        # Make sure it was created after the current subscription, otherwise
        # it is a cancellation for a previous subscription
        created => { '>' => $current_created },
    })->order_by('-id')->first;

    if ($cancellation_report) {
        $self->_vprint("  Active cancellation report " . $cancellation_report->id . " already exists");
        return;
    }

    $cancellation_report
        = $self->create_cancellation_report( $report, $reason );

    $self->_vprint("  Created cancellation report " . $cancellation_report->id);

    my $payment_method = $report->get_extra_field_value('payment_method') || 'credit_card';
    if ($payment_method eq 'direct_debit') {
        $self->_cancel_direct_debit($report);
    } else {
        # Nothing to do for credit card
    }
}

sub create_cancellation_report {
    my ( $self, $existing_report, $reason ) = @_;

    my %cancellation_params = (
        state => 'confirmed',
        confirmed => \'current_timestamp',
        send_state => 'sent',
        category => 'Cancel Garden Subscription',
        title => 'Garden Subscription - Cancel',
        detail => '', # Populated below
        user_id => $self->cobrand->body->comment_user_id,
        name => $self->cobrand->body->comment_user->name,
    );
    for (qw/
        postcode
        latitude
        longitude
        bodies_str
        areas
        used_map
        anonymous
        cobrand
        cobrand_data
        send_questionnaire
        non_public
    /) {
        $cancellation_params{$_} = $existing_report->$_;
    }

    # Initiate report
    my $cancellation_report = FixMyStreet::DB->resultset('Problem')
        ->create( \%cancellation_params );

    # Metadata
    my $existing_meta = $existing_report->get_extra_metadata;
    my %cancellation_meta
        = %$existing_meta{qw/property_address direct_debit_contract_id/};
    $cancellation_report->set_extra_metadata(%cancellation_meta);

    # Set 'detail' using category & property_address
    $cancellation_report->detail(
        $cancellation_params{category} . "\n\n" . $cancellation_meta{property_address} );

    # Extra fields
    my $existing_extra = $existing_report->get_extra_fields;
    my $match_str = join '|', qw/
        uprn
        property_id
        payment_method
        customer_external_ref
        direct_debit_reference
    /;
    my @cancellation_extra
        = grep { $_->{name} =~ /^($match_str)$/ } @$existing_extra;
    push @cancellation_extra, {
        name  => 'reason',
        value => 'Cancelled on Agile end: '
            . ( $reason || 'No reason provided' )
    };
    $cancellation_report->set_extra_fields(@cancellation_extra);

    $cancellation_report->update;

    return $cancellation_report;
}

sub _cancel_direct_debit {
    my ($self, $original_report) = @_;

    my $i = $self->cobrand->get_dd_integration;
    unless ($i) {
        $self->_vprint("  WARNING: Could not get Direct Debit integration object. Unable to cancel at source.");
        return;
    }

    # Check if we have a contract ID in metadata (modern WasteWorks)
    my $contract_id = $original_report->get_extra_metadata('direct_debit_contract_id');

    # For legacy pre-WasteWorks subscriptions, look up by UPRN
    my $legacy_contract_ids;
    if (!$contract_id) {
        $legacy_contract_ids = $self->cobrand->waste_get_legacy_contract_ids($original_report);
        if (!$legacy_contract_ids) {
            $self->_vprint("  WARNING: No contract ID in metadata and no legacy contracts found for UPRN");
            return;
        }
        $self->_vprint("  Found " . scalar(@$legacy_contract_ids) . " legacy contract(s) to try");
    }

    $self->_vprint("  Cancelling Direct Debit plan" . ($contract_id ? " with contract ID $contract_id" : ""));

    my $resp = $i->cancel_plan({
        report => $original_report,
        $legacy_contract_ids ? (contract_ids => $legacy_contract_ids) : (),
    });

    # TODO Set a flag on report if failure here?

    if ( ref $resp eq 'HASH' && $resp->{error} ) {
        $self->_vprint(
            "  Failed to send cancellation request to Direct Debit provider: $resp->{error}"
        );
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
