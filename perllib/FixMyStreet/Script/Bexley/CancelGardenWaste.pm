=head1 NAME

FixMyStreet::Script::Bexley::CancelGardenWaste - cancel garden waste subscriptions
from Agile or Access PaySuite

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

sub cancel_from_agile {
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

    # Find active garden subscription report for this UPRN
    my $original_report = $self->get_original_report( uprn => $uprn );

    # See if there is an existing cancellation report for current subscription
    my $cancellation_report
        = $self->get_existing_cancellation($original_report);
    return if $cancellation_report;

    $cancellation_report
        = $self->create_cancellation_report( $original_report, 1, $reason );

    $self->_vprint("  Created cancellation report " . $cancellation_report->id);

    my $payment_method = $original_report->get_extra_field_value('payment_method') || 'credit_card';
    if ($payment_method eq 'direct_debit') {
        $self->_cancel_direct_debit($original_report);
    } else {
        # Nothing to do for credit card
    }
}

sub cancel_from_aps {
    my ( $self, $dd_contract_id, $reason ) = @_;

    $self->_vprint("Attempting to cancel subscription for DD contract ID $dd_contract_id");

    # Find active garden subscription report for this UPRN
    my $original_report = $self->get_original_report( dd_contract_id => $dd_contract_id );

    # See if there is an existing cancellation report for current subscription
    my $cancellation_report
        = $self->get_existing_cancellation($original_report);
    return if $cancellation_report;

    $cancellation_report
        = $self->create_cancellation_report( $original_report, 0, $reason );

    $self->_vprint("  Created cancellation report " . $cancellation_report->id);
}

# Based on Controller/Waste.pm->get_original_sub
sub get_original_report {
    my ( $self, %args ) = @_;

    my $uprn = $args{uprn};
    my $dd_contract_id = $args{dd_contract_id};

    my $extra = $uprn
        ? { '@>' => encode_json({ '_fields' => [ { name => 'uprn', value => $uprn } ] }) }
        : { '@>' => encode_json({ direct_debit_contract_id => $dd_contract_id }) };

    my $report = $self->cobrand->problems->search({
        category => 'Garden Subscription',
        title => ['Garden Subscription - New', 'Garden Subscription - Renew'],
        extra => $extra,
        state => { '!=' => 'hidden' },
    })->order_by('-id')->first;

    unless ($report) {
        $self->_vprint( "  No active garden subscription found for "
                . ( $uprn ? "UPRN $uprn" : "DD contract ID $dd_contract_id" )
        );
        return;
    }

    $self->_vprint("  Found active report " . $report->id);
    return $report;
}

sub get_existing_cancellation {
    my ( $self, $original_report ) = @_;

    # See if there is an existing cancellation report for current subscription
    my $dtp = FixMyStreet::DB->schema->storage->datetime_parser;
    my $original_created = $dtp->format_datetime( $original_report->created );

    my $uprn = $original_report->get_extra_field_value('uprn');

    my $cancellation_report = $self->cobrand->problems->search({
        category => 'Cancel Garden Subscription',
        extra => { '@>' => encode_json({ "_fields" => [ { name => "uprn", value => $uprn } ] }) },
        state => { '!=' => 'hidden' },
        # Make sure it was created after the current subscription, otherwise
        # it is a cancellation for a previous subscription
        created => { '>' => $original_created },
    })->order_by('-id')->first;

    if ($cancellation_report) {
        $self->_vprint("  Active cancellation report " . $cancellation_report->id . " already exists");
        return $cancellation_report;
    } else {
        return;
    }
}

sub create_cancellation_report {
    my ( $self, $existing_report, $from_agile, $reason ) = @_;

warn "====\n\t" . $self->cobrand->moniker . "\n====";
warn "====\n\t" . "BODY:" . "\n====";
use Data::Dumper;
$Data::Dumper::Indent = 1;
$Data::Dumper::Maxdepth = 3;
$Data::Dumper::Sortkeys = 1;
warn Dumper { $self->cobrand->body->get_columns };

    my %cancellation_params = (
        state => 'confirmed',
        category => 'Cancel Garden Subscription',
        title => 'Garden Subscription - Cancel',
        detail => '', # Populated below
        used_map => 0,
        user_id => $self->cobrand->body->comment_user_id,
        name => $self->cobrand->body->comment_user->name,

        $from_agile ? ( send_state => 'sent' ) : (),
    );
    for (qw/
        postcode
        latitude
        longitude
        bodies_str
        areas
        anonymous
        cobrand
        cobrand_data
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
        value => 'Cancelled in '
            . ( $from_agile ? 'Agile' : 'Access PaySuite' ) . ': '
            . ( $reason || 'No reason provided' ),
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

    my $payer_ref = $original_report->get_extra_metadata('direct_debit_contract_id');
    if (!$payer_ref) {
        $self->_vprint("  WARNING: Direct debit cancellation failed: direct_debit_contract_id not found on original report " . $original_report->id);
        return;
    }

    $self->_vprint("  Cancelling Direct Debit plan with payer reference $payer_ref");
    my $resp = $i->cancel_plan({
        report => $original_report,
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
