use strict; use warnings;

use Test::More;
use Test::MockModule;
use Test::MockTime ':all';
use Path::Tiny;
use DateTime;

use Integrations::Bottomline;

my $integ = Test::MockModule->new('Integrations::Bottomline');
$integ->mock('config', sub { return { dd_sun => 'sun', dd_client_id => 'client' }; } );
$integ->mock('call', sub {
    my ($self, $method, $data) = @_;

    if ( $method eq 'query/execute#CollectionHistoryDates' ) {
        if ( $data->{resultsPage}->{firstResult} == 0 ) {
            return {
                rows => [
                            { values => [ { resultValues => [ { value => {
                                '@type' => "Instruction",
                                amount => 10.00,
                                paymentType => "AUDDIS",
                                lastUpdated => "16/03/2021",
                                paymentDate => "16/03/2021",
                                accountName => "A Payer",
                                accountNumber => 123,
                                reference => "RBK-NEW_SUB-654321",
                                sortCode => "12345",
                                status => "SUCCESS",
                                transactionCode => "01",
                                created => "06/03/20201",
                                modelId => 1,
                                profileId => 1,
                                mandateId => 1,
                                applicationId => 1,
                                instructionId => 1,
                                batchId => 1,
                                submissionId => 1,
                                retryCount => 0,
                                serviceUserNumber => 1,
                            } } ] } ] },
                            { values => [ { resultValues => [ { value => {
                                '@type' => "long",
                                '$value' => 55
                            } } ] } ] },
                        ]
                };
        } else {
            return {
                rows => [
                            { values => [ { resultValues => [ { value => {
                                '@type' => "Instruction",
                                amount => 10.00,
                                lastUpdated => "16/03/2021",
                                paymentDate => "16/03/2021",
                                accountName => "A Payer",
                                accountNumber => 123,
                                reference => "RBK-AD_HOC_SKIPPED-954325",
                                sortCode => "12345",
                                status => "SUCCESS",
                                transactionCode => "01",
                                created => "06/03/20201",
                                modelId => 1,
                                profileId => 13,
                                mandateId => 13,
                                applicationId => 1,
                                instructionId => 13,
                                batchId => 1,
                                submissionId => 1,
                                retryCount => 0,
                                serviceUserNumber => 1,
                            } } ] } ] },
                            { values => [ { resultValues => [ { value => {
                                '@type' => "long",
                                '$value' => 55
                            } } ] } ] },
                        ]
                    };
        }
    } elsif ( $method eq 'query/execute#CollectionHistoryStatus' ) {
        # test no results
        return {};
    }
});

my $i = Integrations::Bottomline->new();

subtest 'check pagination' => sub {

    my $res = $i->get_recent_payments({
        start => DateTime->new(day => 1, month => 1, year => 2022),
        end => DateTime->new(day => 1, month => 2, year => 2022),
    });

    is_deeply $res, [
        {
            '@type' => "Instruction",
            amount => 10.00,
            paymentType => "AUDDIS",
            lastUpdated => "16/03/2021",
            paymentDate => "16/03/2021",
            accountName => "A Payer",
            accountNumber => 123,
            reference => "RBK-NEW_SUB-654321",
            sortCode => "12345",
            status => "SUCCESS",
            transactionCode => "01",
            created => "06/03/20201",
            modelId => 1,
            profileId => 1,
            mandateId => 1,
            applicationId => 1,
            instructionId => 1,
            batchId => 1,
            submissionId => 1,
            retryCount => 0,
            serviceUserNumber => 1,
        },
        {
            '@type' => "Instruction",
            amount => 10.00,
            lastUpdated => "16/03/2021",
            paymentDate => "16/03/2021",
            accountName => "A Payer",
            accountNumber => 123,
            reference => "RBK-AD_HOC_SKIPPED-954325",
            sortCode => "12345",
            status => "SUCCESS",
            transactionCode => "01",
            created => "06/03/20201",
            modelId => 1,
            profileId => 13,
            mandateId => 13,
            applicationId => 1,
            instructionId => 13,
            batchId => 1,
            submissionId => 1,
            retryCount => 0,
            serviceUserNumber => 1,
        },
    ], "pages through things";
};

subtest 'check pagination when no results' => sub {
    my $res = $i->get_payments_with_status({ status => "PENDING" });
    is_deeply  $res, [], "returns empty array if no results";
};

done_testing();
