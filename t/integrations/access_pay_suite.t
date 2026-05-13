use strict;
use warnings;

use DateTime;
use FixMyStreet::TestMech;  # bootstraps config so FixMyStreet->local_time_zone works
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

# In-memory stand-in for a Problem row: get/set_extra_metadata back onto a hash,
# update is a no-op. Lets us assert against recorded metadata without the DB.
sub mock_report {
    my %metadata = @_;
    my $stored = { %metadata };
    my $report = Test::MockObject->new;
    $report->mock('id', sub { 135 });
    $report->mock( 'get_extra_metadata', sub {
        my ( $self, $key ) = @_;
        return $stored->{$key};
    });
    $report->mock( 'set_extra_metadata', sub {
        my ( $self, %data ) = @_;
        $stored->{$_} = $data{$_} for keys %data;
    });
    $report->mock( 'unset_extra_metadata', sub {
        my ( $self, $key ) = @_;
        delete $stored->{$key};
    });
    $report->mock( 'update', sub { } );
    return $report;
}

subtest 'cancel_plan uses metadata contract_id when present' => sub {
    my $archived_contract;
    $mock->mock( 'archive_contract', sub {
        my ( $self, $contract_id ) = @_;
        $archived_contract = $contract_id;
        return 1;
    });

    my $report = mock_report();
    my $result = $integration->cancel_plan({
        report => $report,
        dd_reference => 'METADATA-CONTRACT-123',
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

subtest 'cancel_plan records success metadata' => sub {
    $mock->mock( 'call', sub { {} } );
    my $report = mock_report();

    is $integration->cancel_plan({ dd_reference => 'PAYER123', report => $report }), 1, 'cancel_plan returns success';

    like $report->get_extra_metadata('direct_debit_cancellation_date'),
        qr/^\d{4}-\d{2}-\d{2}T/, 'cancellation date set';

    $mock->unmock('call');
};

subtest 'cancel_plan records failure metadata' => sub {
    $mock->mock( 'call', sub { { error => 'Provider down' } } );
    my $report = mock_report();

    my $resp = $integration->cancel_plan({ dd_reference => 'PAYER123', report => $report });
    is $resp->{error}, 'Provider down', 'error returned to caller';

    my $info = ($report->get_extra_metadata('direct_debit_errors') || {})->{cancellation} || {};
    is $info->{error}, 'Provider down', 'error recorded';
    is $info->{failures}, 1, 'failure count = 1';
    like $info->{last_failed_at}, qr/^\d{4}-\d{2}-\d{2}T/, 'timestamp set';
    ok !$report->get_extra_metadata('direct_debit_cancellation_date'),
        'no success date on failure';

    $mock->unmock('call');
};

subtest 'cancel_plan increments failure counter on repeat' => sub {
    $mock->mock( 'call', sub { { error => 'Still down' } } );
    my $report = mock_report(
        direct_debit_errors => { cancellation => { failures => 2 } },
    );

    $integration->cancel_plan({ dd_reference => 'PAYER123', report => $report });

    is $report->get_extra_metadata('direct_debit_errors')->{cancellation}{failures}, 3,
        'failure count incremented from existing value';

    $mock->unmock('call');
};

subtest 'amend_plan records failure metadata' => sub {
    $mock->mock( 'call', sub { { error => 'Amend boom' } } );
    my $report = mock_report();

    is $integration->amend_plan({
        dd_reference => 'PAYER123',
        report => $report, amount => '50.00' }),
        undef, 'amend_plan returns undef on provider error';

    my $info = ($report->get_extra_metadata('direct_debit_errors') || {})->{amend} || {};
    is $info->{error}, 'Amend boom', 'error recorded';
    is $info->{failures}, 1, 'failure count = 1';
    like $info->{last_failed_at}, qr/^\d{4}-\d{2}-\d{2}T/, 'timestamp set';
    is $info->{context}{amount}, '50.00', 'amount stashed for retry';

    $mock->unmock('call');
};

subtest 'amend_plan records failure when DD reference missing' => sub {
    my $report = mock_report();

    is $integration->amend_plan({
        # no dd_reference
        report => $report, amount => '50.00' }),
        undef, 'amend_plan returns undef when dd_reference missing';

    my $info = ($report->get_extra_metadata('direct_debit_errors') || {})->{amend} || {};
    like $info->{error}, qr/No direct debit contract ID/, 'error recorded';
    is $info->{context}{amount}, '50.00', 'amount stashed for retry';
};

subtest 'one_off_payment records failure metadata' => sub {
    $mock->mock( 'call', sub { { error => 'Adhoc boom' } } );
    my $report = mock_report();
    my $date = DateTime->new( year => 2026, month => 5, day => 15 );

    is $integration->one_off_payment({
        dd_reference => 'PAYER123',
        report => $report,
        amount => '12.50',
        date => $date,
    }), undef, 'one_off_payment returns undef on provider error';

    my $info = ($report->get_extra_metadata('direct_debit_errors') || {})->{one_off} || {};
    is $info->{error}, 'Adhoc boom', 'error recorded';
    is $info->{failures}, 1, 'failure count = 1';
    like $info->{last_failed_at}, qr/^\d{4}-\d{2}-\d{2}T/, 'timestamp set';
    is $info->{context}{amount}, '12.50', 'amount stashed for retry';
    is $info->{context}{date}, $date->iso8601, 'date stashed for retry';

    $mock->unmock('call');
};

subtest 'one_off_payment records failure when DD reference missing' => sub {
    my $report = mock_report();
    my $date = DateTime->new( year => 2026, month => 5, day => 15 );

    is $integration->one_off_payment({
        # no dd_reference
        report => $report,
        amount => '12.50',
        date => $date,
    }), undef, 'one_off_payment returns undef when dd_reference missing';

    my $info = ($report->get_extra_metadata('direct_debit_errors') || {})->{one_off} || {};
    like $info->{error}, qr/No direct debit contract ID/, 'error recorded';
    is $info->{context}{amount}, '12.50', 'amount stashed for retry';
    is $info->{context}{date}, $date->iso8601, 'date stashed for retry';
};

subtest 'cancel_plan clears prior failure on success' => sub {
    $mock->mock( 'call', sub { {} } );
    my $report = mock_report(
        direct_debit_errors => {
            cancellation => { error => 'old', failures => 2, last_failed_at => '...' },
            amend        => { error => 'unrelated', failures => 1, last_failed_at => '...' },
        },
    );

    is $integration->cancel_plan({ dd_reference => 'PAYER123', report => $report }), 1, 'cancel_plan returns success';

    my $errors = $report->get_extra_metadata('direct_debit_errors') || {};
    ok !$errors->{cancellation}, 'cancellation entry cleared on success';
    ok $errors->{amend}, 'unrelated amend entry preserved';

    $mock->unmock('call');
};

subtest 'amend_plan clears prior failure on success' => sub {
    $mock->mock( 'call', sub { {} } );
    my $report = mock_report(
        direct_debit_errors => { amend => { error => 'old', failures => 1 } },
    );

    $integration->amend_plan({ dd_reference => 'PAYER123', report => $report, amount => '50.00' });

    ok !$report->get_extra_metadata('direct_debit_errors'),
        'direct_debit_errors fully cleared when last entry removed';

    $mock->unmock('call');
};

subtest 'one_off_payment clears prior failure on success' => sub {
    $mock->mock( 'call', sub { {} } );
    my $report = mock_report(
        direct_debit_errors => { one_off => { error => 'old', failures => 1 } },
    );

    is $integration->one_off_payment({
        dd_reference => 'PAYER123',
        report => $report,
        amount => '12.50',
        date => DateTime->now,
    }), 1, 'one_off_payment returns success';

    ok !$report->get_extra_metadata('direct_debit_errors'),
        'direct_debit_errors fully cleared when last entry removed';

    $mock->unmock('call');
};

done_testing;
