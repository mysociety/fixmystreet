use strict;
use warnings;

use Test::More;
use Test::MockModule;
use Test::MockObject;

use Integrations::AccessPaySuite;

my $integration = Integrations::AccessPaySuite->new(
    config => {
        endpoint   => 'http://example.com',
        client_code => 'TEST',
        api_key    => 'test-key',
    }
);

my $mock = Test::MockModule->new('Integrations::AccessPaySuite');

# Helper to create mock report with specified metadata
sub mock_report {
    my %metadata = @_;
    my $report = Test::MockObject->new;
    $report->mock( 'get_extra_metadata', sub {
        my ( $self, $key ) = @_;
        return $metadata{$key};
    });
    return $report;
}

subtest 'cancel_plan uses metadata contract_id when present' => sub {
    my $archived_contract;
    $mock->mock( 'archive_contract', sub {
        my ( $self, $contract_id ) = @_;
        $archived_contract = $contract_id;
        return 1;
    });

    my $report = mock_report( direct_debit_contract_id => 'METADATA-CONTRACT-123' );

    my $result = $integration->cancel_plan({
        report       => $report,
        contract_ids => ['PARAM-CONTRACT-456'],  # Should be ignored
    });

    is $result, 1, 'cancel_plan returns success';
    is $archived_contract, 'METADATA-CONTRACT-123',
        'Uses contract ID from metadata, not from contract_ids parameter';

    $mock->unmock('archive_contract');
};

subtest 'cancel_plan uses provided contract_ids when metadata empty' => sub {
    my $archived_contract;
    $mock->mock( 'archive_contract', sub {
        my ( $self, $contract_id ) = @_;
        $archived_contract = $contract_id;
        return 1;
    });

    my $report = mock_report();  # No metadata

    my $result = $integration->cancel_plan({
        report       => $report,
        contract_ids => ['PARAM-CONTRACT-456'],
    });

    is $result, 1, 'cancel_plan returns success';
    is $archived_contract, 'PARAM-CONTRACT-456',
        'Uses contract ID from contract_ids parameter';

    $mock->unmock('archive_contract');
};

subtest 'cancel_plan returns error when no contract IDs available' => sub {
    my $report = mock_report();  # No metadata

    my $result = $integration->cancel_plan({
        report => $report,
        # No contract_ids parameter either
    });

    is ref($result), 'HASH', 'Returns a hashref';
    like $result->{error}, qr/No contract ID found/,
        'Error message indicates no contract ID';
};

subtest 'cancel_plan tries all contracts' => sub {
    my @archived_contracts;
    $mock->mock( 'archive_contract', sub {
        my ( $self, $contract_id ) = @_;
        push @archived_contracts, $contract_id;
        # First contract fails, second succeeds, third fails
        return $contract_id eq 'CONTRACT-2' ? 1 : { error => 'Not found' };
    });

    my $report = mock_report();

    my $result = $integration->cancel_plan({
        report       => $report,
        contract_ids => ['CONTRACT-1', 'CONTRACT-2', 'CONTRACT-3'],
    });

    is $result, 1, 'cancel_plan returns success';
    is_deeply \@archived_contracts, ['CONTRACT-1', 'CONTRACT-2', 'CONTRACT-3'],
        'Tries all contracts regardless of success or failure';

    $mock->unmock('archive_contract');
};

subtest 'cancel_plan ignores errors and returns success' => sub {
    my @archived_contracts;
    $mock->mock( 'archive_contract', sub {
        my ( $self, $contract_id ) = @_;
        push @archived_contracts, $contract_id;
        return { error => "Failed for $contract_id" };
    });

    my $report = mock_report();

    my $result = $integration->cancel_plan({
        report       => $report,
        contract_ids => ['CONTRACT-A', 'CONTRACT-B'],
    });

    is $result, 1, 'Returns success even when all contracts fail';
    is_deeply \@archived_contracts, ['CONTRACT-A', 'CONTRACT-B'],
        'Attempts all contracts despite errors';

    $mock->unmock('archive_contract');
};

done_testing;
