use CGI::Simple;
use Test::MockModule;
use Test::MockTime qw(:all);
use Test::Warn;
use DateTime;
use JSON::MaybeXS;
use Test::Output;
use FixMyStreet::TestMech;
use FixMyStreet::SendReport::Open311;
use FixMyStreet::Script::Reports;
use FixMyStreet::Script::Alerts;
use Open311::PostServiceRequestUpdates;
use List::Util 'any';
use Regexp::Common 'URI';
my $mech = FixMyStreet::TestMech->new;

# disable info logs for this test run
FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

# Create test data
my $user = $mech->create_user_ok( 'kingston@example.com', name => 'Kingston' );
my $body = $mech->create_body_ok( 2480, 'Kingston upon Thames Council', {
    can_be_devolved => 1, send_extended_statuses => 1, comment_user => $user,
    send_method => 'Open311', endpoint => 'http://endpoint.example.com', jurisdiction => 'FMS', api_key => 'test', send_comments => 1
}, {
    cobrand => 'kingston',
});
my $staffuser = $mech->create_user_ok( 'staff@example.com', name => 'Staffie', from_body => $body );


FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'kingston',
    MAPIT_URL => 'http://mapit.uk/',
    COBRAND_FEATURES => {
        bottomline => { kingston => { } },
    }
}, sub {
    subtest 'check direct debit reconcilliation' => sub {
        set_fixed_time('2021-03-19T12:00:00Z'); # After sample food waste collection
        my $echo = Test::MockModule->new('Integrations::Echo');
        $echo->mock('GetServiceUnitsForObject' => sub {
            my ($self, $id) = @_;

            if ( $id == 54321 ) {
                return [ {
                    Id => 1005,
                    ServiceId => 409,
                    ServiceName => 'Garden waste collection',
                    ServiceTasks => { ServiceTask => {
                        TaskTypeId => 2247,
                        Id => 405,
                        ScheduleDescription => 'every other Monday',
                        Data => { ExtensibleDatum => [ {
                            DatatypeName => 'SLWP - Containers',
                            ChildData => { ExtensibleDatum => {
                                DatatypeName => 'Quantity',
                                Value => 2,
                            } },
                        } ] },
                        ServiceTaskSchedules => { ServiceTaskSchedule => [ {
                            EndDate => { DateTime => '2020-01-01T00:00:00Z' },
                            LastInstance => {
                                OriginalScheduledDate => { DateTime => '2019-12-31T00:00:00Z' },
                                CurrentScheduledDate => { DateTime => '2019-12-31T00:00:00Z' },
                            },
                        }, {
                            EndDate => { DateTime => '2021-03-30T00:00:00Z' },
                            NextInstance => {
                                CurrentScheduledDate => { DateTime => '2020-06-01T00:00:00Z' },
                                OriginalScheduledDate => { DateTime => '2020-06-01T00:00:00Z' },
                            },
                            LastInstance => {
                                OriginalScheduledDate => { DateTime => '2020-05-18T00:00:00Z' },
                                CurrentScheduledDate => { DateTime => '2020-05-18T00:00:00Z' },
                                Ref => { Value => { anyType => [ 567, 890 ] } },
                            },
                        }
                    ] }
                } } } ];
            }
            if ( $id == 54322 || $id == 54324 || $id == 84324 || $id == 154323 ) {
                return [ {
                    Id => 1005,
                    ServiceId => 409,
                    ServiceName => 'Garden waste collection',
                    ServiceTasks => { ServiceTask => {
                        TaskTypeId => 2247,
                        Id => 405,
                        ScheduleDescription => 'every other Monday',
                        Data => { ExtensibleDatum => [ {
                            DatatypeName => 'SLWP - Containers',
                            ChildData => { ExtensibleDatum => {
                                DatatypeName => 'Quantity',
                                Value => 1,
                            } },
                        } ] },
                        ServiceTaskSchedules => { ServiceTaskSchedule => [ {
                            EndDate => { DateTime => '2020-01-01T00:00:00Z' },
                            LastInstance => {
                                OriginalScheduledDate => { DateTime => '2019-12-31T00:00:00Z' },
                                CurrentScheduledDate => { DateTime => '2019-12-31T00:00:00Z' },
                            },
                        }, {
                            EndDate => { DateTime => '2021-03-30T00:00:00Z' },
                            NextInstance => {
                                CurrentScheduledDate => { DateTime => '2020-06-01T00:00:00Z' },
                                OriginalScheduledDate => { DateTime => '2020-06-01T00:00:00Z' },
                            },
                            LastInstance => {
                                OriginalScheduledDate => { DateTime => '2020-05-18T00:00:00Z' },
                                CurrentScheduledDate => { DateTime => '2020-05-18T00:00:00Z' },
                                Ref => { Value => { anyType => [ 567, 890 ] } },
                            },
                        }
                    ] }
                } } } ];
            }
        });

        my $id_replacements = {};

        my $ad_hoc_orig = setup_dd_test_report({
            'Request_Type' => 1,
            'Subscription_Details_Quantity' => 1,
            'payment_method' => 'direct_debit',
            'property_id' => '54325',
            'uprn' => '654325',
        });
        $ad_hoc_orig->set_extra_metadata('dd_date', '01/01/2021');
        $ad_hoc_orig->update;

        $id_replacements->{AD_HOC_ORIG} = $ad_hoc_orig->id;

        my $ad_hoc = setup_dd_test_report({
            'Request_Type' => 3,
            'Subscription_Details_Quantity' => 1,
            'payment_method' => 'direct_debit',
            'property_id' => '54325',
            'uprn' => '654325',
        });
        $ad_hoc->set_extra_metadata('payerReference', get_reference("RBK-AD_HOC_ORIG-654325", $id_replacements));
        $ad_hoc->state('unconfirmed');
        $ad_hoc->update;

        $id_replacements->{AD_HOC} = $ad_hoc->id;

        my $ad_hoc_processed = setup_dd_test_report({
            'Request_Type' => 3,
            'Subscription_Details_Quantity' => 1,
            'payment_method' => 'direct_debit',
            'property_id' => '54426',
            'uprn' => '654326',
        });
        $ad_hoc_processed->set_extra_metadata('dd_date' => '2021-03-16T00:00:00.000');
        $ad_hoc_processed->update;

        $id_replacements->{AD_HOC_PROCESSED} = $ad_hoc_processed->id;

        my $ad_hoc_skipped = setup_dd_test_report({
            'Request_Type' => 3,
            'Subscription_Details_Quantity' => 1,
            'payment_method' => 'direct_debit',
            'property_id' => '94325',
            'uprn' => '954325',
        });
        $ad_hoc_skipped->state('unconfirmed');
        $ad_hoc_skipped->update;
        $id_replacements->{AD_HOC_SKIPPED} = $ad_hoc_skipped->id;

        my $hidden = setup_dd_test_report({
            'Request_Type' => 1,
            'Subscription_Details_Quantity' => 1,
            'payment_method' => 'direct_debit',
            'property_id' => '54399',
            'uprn' => '554399',
        });
        $hidden->state('hidden');
        $hidden->update;
        $id_replacements->{HIDDEN} = $hidden->id;

        my $cc_to_ignore = setup_dd_test_report({
            'Request_Type' => 1,
            'Subscription_Details_Quantity' => 1,
            'payment_method' => 'credit_card',
            'property_id' => '54399',
            'uprn' => '554399',
        });
        $cc_to_ignore->state('unconfirmed');
        $cc_to_ignore->update;
        $id_replacements->{CC_TO_IGNORE} = $cc_to_ignore->id;

        my $integ = Test::MockModule->new('Integrations::Bottomline');
        $integ->mock('config', sub { return { dd_sun => 'sun', dd_client_id => 'client' }; } );
        $integ->mock('call', sub {
            my ($self, $method, $data) = @_;

            if ( $method eq 'query/execute#CollectionHistoryDates' ) {
            return {
                rows => [
                            { values => [ { resultValues => [ { value => {   # new sub
                                '@type' => "Instruction",
                                amount => 10.00,
                                paymentType => "AUDDIS",
                                lastUpdated => "2021-03-16T00:00:00.000",
                                paymentDate => "2021-03-16T00:00:00.000",
                                accountName => "A Payer",
                                accountNumber => 123,
                                reference => get_reference("RBK-NEW_SUB-654321", $id_replacements),
                                sortCode => "12345",
                                status => "SUCCESS",
                                transactionCode => "01",
                                created => "2021-03-06T00:00:00.000",
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
                            { values => [ { resultValues => [ { value => {   # unhandled new sub
                                '@type' => "Instruction",
                                amount => 10.00,
                                lastUpdated => "2021-03-16T00:00:00.000",
                                paymentDate => "2021-03-16T00:00:00.000",
                                accountName => "A Payer",
                                accountNumber => 123,
                                reference => get_reference("RBK-3000-554321", $id_replacements),
                                sortCode => "12345",
                                status => "SUCCESS",
                                transactionCode => "01",
                                created => "2021-03-06T00:00:00.000",
                                modelId => 1,
                                profileId => 2,
                                mandateId => 2,
                                applicationId => 1,
                                instructionId => 2,
                                batchId => 1,
                                submissionId => 1,
                                retryCount => 0,
                                serviceUserNumber => 1,
                            } } ] } ] },
                            { values => [ { resultValues => [ { value => {   # hidden new sub
                                '@type' => "Instruction",
                                amount => 10.00,
                                lastUpdated => "2021-03-16T00:00:00.000",
                                paymentDate => "2021-03-16T00:00:00.000",
                                accountName => "A Payer",
                                accountNumber => 123,
                                reference => get_reference("RBK-HIDDEN-554399", $id_replacements),
                                sortCode => "12345",
                                status => "SUCCESS",
                                transactionCode => "01",
                                created => "2021-03-06T00:00:00.000",
                                modelId => 1,
                                profileId => 3,
                                mandateId => 3,
                                applicationId => 1,
                                instructionId => 3,
                                batchId => 1,
                                submissionId => 1,
                                retryCount => 0,
                                serviceUserNumber => 1,
                            } } ] } ] },
                            { values => [ { resultValues => [ { value => {   # ad hoc already processed
                                '@type' => "Instruction",
                                comments => $ad_hoc_processed->id,
                                amount => 10.00,
                                lastUpdated => "2021-03-16T00:00:00.000",
                                paymentDate => "2021-03-16T00:00:00.000",
                                accountName => "A Payer",
                                accountNumber => 123,
                                reference => get_reference("RBK-AD_HOC_PROCESSED-654326", $id_replacements),
                                sortCode => "12345",
                                status => "SUCCESS",
                                transactionCode => "17",
                                created => "2021-03-06T00:00:00.000",
                                modelId => 1,
                                profileId => 4,
                                mandateId => 4,
                                applicationId => 1,
                                instructionId => 1,
                                batchId => 1,
                                submissionId => 4,
                                retryCount => 0,
                                serviceUserNumber => 1,
                            } } ] } ] },
                            { values => [ { resultValues => [ { value => {   # renewal
                                '@type' => "Instruction",
                                amount => 10.00,
                                lastUpdated => "2021-03-16T00:00:00.000",
                                paymentDate => "2021-03-16T00:00:00.000",
                                accountName => "A Payer",
                                accountNumber => 123,
                                reference => get_reference("RBK-SUB_FOR_RENEWAL-654322", $id_replacements),
                                sortCode => "12345",
                                status => "SUCCESS",
                                transactionCode => "17",
                                created => "2021-03-06T00:00:00.000",
                                modelId => 1,
                                profileId => 5,
                                mandateId => 5,
                                applicationId => 1,
                                instructionId => 5,
                                batchId => 1,
                                submissionId => 1,
                                retryCount => 0,
                                serviceUserNumber => 1,
                            } } ] } ] },
                            { values => [ { resultValues => [ { value => {   # renewal already handled
                                '@type' => "Instruction",
                                amount => 10.00,
                                lastUpdated => "2021-03-16T00:00:00.000",
                                paymentDate => "2021-03-16T00:00:00.000",
                                accountName => "A Payer",
                                accountNumber => 123,
                                reference => get_reference("RBK-PROCESSED_RENEWAL-654324", $id_replacements),
                                sortCode => "12345",
                                status => "SUCCESS",
                                transactionCode => "17",
                                created => "2021-03-06T00:00:00.000",
                                modelId => 1,
                                profileId => 6,
                                mandateId => 6,
                                applicationId => 1,
                                instructionId => 6,
                                batchId => 1,
                                submissionId => 1,
                                retryCount => 0,
                                serviceUserNumber => 1,
                            } } ] } ] },
                            { values => [ { resultValues => [ { value => {   # renewal but payment too new
                                '@type' => "Instruction",
                                amount => 10.00,
                                lastUpdated => "2021-03-18T00:00:00.000",
                                paymentDate => "2021-03-19T00:00:00.000",
                                accountName => "A Payer",
                                accountNumber => 123,
                                reference => get_reference("RBK654329", $id_replacements),
                                sortCode => "12345",
                                status => "SUCCESS",
                                transactionCode => "17",
                                created => "2021-03-06T00:00:00.000",
                                modelId => 1,
                                profileId => 7,
                                mandateId => 7,
                                applicationId => 1,
                                instructionId => 7,
                                batchId => 1,
                                submissionId => 1,
                                retryCount => 0,
                                serviceUserNumber => 1,
                            } } ] } ] },
                            { values => [ { resultValues => [ { value => {   # renewal but nothing in echo
                                '@type' => "Instruction",
                                amount => 10.00,
                                lastUpdated => "2021-03-16T00:00:00.000",
                                paymentDate => "2021-03-16T00:00:00.000",
                                accountName => "A Payer",
                                accountNumber => 123,
                                reference => get_reference("RBK-RENEWAL_NOTHING_IN_ECHO-754322", $id_replacements),
                                sortCode => "12345",
                                status => "SUCCESS",
                                transactionCode => "17",
                                created => "2021-03-06T00:00:00.000",
                                modelId => 1,
                                profileId => 8,
                                mandateId => 8,
                                applicationId => 1,
                                instructionId => 8,
                                batchId => 1,
                                submissionId => 1,
                                retryCount => 0,
                                serviceUserNumber => 1,
                            } } ] } ] },
                            { values => [ { resultValues => [ { value => {   # renewal but nothing in fms
                                '@type' => "Instruction",
                                amount => 10.00,
                                lastUpdated => "2021-03-16T00:00:00.000",
                                paymentDate => "2021-03-16T00:00:00.000",
                                accountName => "A Payer",
                                accountNumber => 123,
                                reference => get_reference("RBK-4000-854324", $id_replacements),
                                sortCode => "12345",
                                status => "SUCCESS",
                                transactionCode => "17",
                                created => "2021-03-06T00:00:00.000",
                                modelId => 1,
                                profileId => 9,
                                mandateId => 9,
                                applicationId => 1,
                                instructionId => 9,
                                batchId => 1,
                                submissionId => 1,
                                retryCount => 0,
                                serviceUserNumber => 1,
                            } } ] } ] },
                            { values => [ { resultValues => [ { value => {   # subsequent renewal from a cc sub
                                '@type' => "Instruction",
                                amount => 10.00,
                                lastUpdated => "2021-03-16T00:00:00.000",
                                paymentDate => "2021-03-16T00:00:00.000",
                                accountName => "A Payer",
                                accountNumber => 123,
                                reference => get_reference("RBK-SUB_FOR_SUBSEQUENT_RENEWAL_FROM_CC_SUB-3654321", $id_replacements),
                                sortCode => "12345",
                                status => "SUCCESS",
                                transactionCode => "17",
                                created => "2021-03-06T00:00:00.000",
                                modelId => 1,
                                profileId => 10,
                                mandateId => 10,
                                applicationId => 1,
                                instructionId => 10,
                                batchId => 1,
                                submissionId => 1,
                                retryCount => 0,
                                serviceUserNumber => 1,
                            } } ] } ] },
                            { values => [ { resultValues => [ { value => {   # renewal from cc payment
                                '@type' => "Instruction",
                                amount => 10.00,
                                lastUpdated => "2021-02-27T00:00:00.000",
                                paymentDate => "2021-03-15T00:00:00.000",
                                accountName => "A Payer",
                                accountNumber => 123,
                                reference => get_reference("RBK-RENEWAL_FROM_CC_SUB-1654321", $id_replacements),
                                sortCode => "12345",
                                status => "SUCCESS",
                                transactionCode => "01",
                                created => "2021-03-06T00:00:00.000",
                                modelId => 1,
                                profileId => 11,
                                mandateId => 11,
                                applicationId => 1,
                                instructionId => 1,
                                batchId => 1,
                                submissionId => 1,
                                retryCount => 0,
                                serviceUserNumber => 1,
                            } } ] } ] },
                            { values => [ { resultValues => [ { value => {   # ad hoc
                                '@type' => "Instruction",
                                comments => $ad_hoc->id,
                                amount => 10.00,
                                lastUpdated => "2021-03-14T00:00:00.000",
                                paymentDate => "2021-03-16T00:00:00.000",
                                accountName => "A Payer",
                                accountNumber => 123,
                                reference => get_reference("RBK-AD_HOC_ORIG-654325", $id_replacements),
                                sortCode => "12345",
                                status => "SUCCESS",
                                transactionCode => "17",
                                created => "2021-03-06T00:00:00.000",
                                modelId => 1,
                                profileId => 12,
                                mandateId => 12,
                                applicationId => 1,
                                instructionId => 12,
                                batchId => 1,
                                submissionId => 1,
                                retryCount => 0,
                                serviceUserNumber => 1,
                            } } ] } ] },
                            { values => [ { resultValues => [ { value => {   # unhandled new sub, ad hoc with same uprn
                                '@type' => "Instruction",
                                amount => 10.00,
                                lastUpdated => "2021-03-16T00:00:00.000",
                                paymentDate => "2021-03-16T00:00:00.000",
                                accountName => "A Payer",
                                accountNumber => 123,
                                reference => get_reference("RBK-AD_HOC_SKIPPED-954325", $id_replacements),
                                sortCode => "12345",
                                status => "SUCCESS",
                                transactionCode => "01",
                                created => "2021-03-06T00:00:00.000",
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
                                '$value' => 13,
                            } } ] } ] },
                        ]
                };
            } elsif ( $method eq 'query/execute#getCancelledPayers' ) {
                return => {
                    rows => [
                            { values => [ { resultValues => [ { value => {   # cancel
                                '@type' => "MandateDTO",
                                payerId => 1,
                                profileId => 200,
                                created => "26/02/2021",
                                lastUpdated => "26/02/2021",
                                accountName => "A Payer",
                                accountNumber => 123,
                                reference => get_reference("RBK-SUB_FOR_CANCEL-654323", $id_replacements),
                                sortCode => "12345",
                                status => "CANCELLED",
                            } } ] } ] },
                            { values => [ { resultValues => [ { value => {   # unhandled cancel
                                '@type' => "MandateDTO",
                                payerId => 24,
                                profileId => 200,
                                created => "21/02/2021",
                                lastUpdated => "26/02/2021",
                                accountName => "A Payer",
                                accountNumber => 123,
                                reference => get_reference("RBK954326", $id_replacements),
                                sortCode => "12345",
                                status => "CANCELLED",
                            } } ] } ] },
                            { values => [ { resultValues => [ { value => {   # unprocessed cancel
                                '@type' => "MandateDTO",
                                payerId => 329,
                                profileId => 200,
                                created => "21/02/2021",
                                lastUpdated => "21/02/2021",
                                accountName => "A Payer",
                                accountNumber => 123,
                                reference => get_reference("RBK-SUB_FOR_UNPROCESSED_CANCEL-854325", $id_replacements),
                                sortCode => "12345",
                                status => "CANCELLED",
                            } } ] } ] },
                            { values => [ { resultValues => [ { value => {   # cancel nothing in echo
                                '@type' => "MandateDTO",
                                payerId => 103,
                                profileId => 200,
                                created => "21/02/2021",
                                lastUpdated => "26/02/2021",
                                accountName => "A Payer",
                                accountNumber => 123,
                                reference => get_reference("RBK-SUB_CANCEL_NOTHING_IN_ECHO-954324", $id_replacements),
                                sortCode => "12345",
                                status => "CANCELLED",
                            } } ] } ] },
                            { values => [ { resultValues => [ { value => {   # cancel no extended data
                                '@type' => "MandateDTO",
                                payerId => 24,
                                profileId => 200,
                                created => "26/02/2021",
                                lastUpdated => "26/02/2021",
                                accountName => "A Payer",
                                accountNumber => 123,
                                reference => get_reference("RBK6654326", $id_replacements),
                                sortCode => "12345",
                                status => "CANCELLED",
                            } } ] } ] },
                            { values => [ { resultValues => [ { value => {
                                '@type' => "long",
                                '$value' => 5,
                            } } ] } ] },
                        ]
                };
            } elsif ( $method eq 'query/execute#getContactFromEmail' ) {
                return {
                    rows => [ {
                      values => [ {
                         resultValues => [ {
                            value => {
                               '@type' => "ContactDTO",
                               id => 1,
                            }
                         } ]
                      } ]
                    } ]
                }
            }
        });

        my $contact = $mech->create_contact_ok(body => $body, category => 'Garden Subscription', email => 'garden@example.com');
        $contact->set_extra_fields(
                { name => 'uprn', required => 1, automated => 'hidden_field' },
                { name => 'property_id', required => 1, automated => 'hidden_field' },
                { name => 'service_id', required => 0, automated => 'hidden_field' },
                { name => 'Request_Type', required => 1, automated => 'hidden_field' },
                { name => 'Subscription_Details_Quantity', required => 1, automated => 'hidden_field' },
                { name => 'Subscription_Details_Containers', required => 1, automated => 'hidden_field' },
                { name => 'Bin_Delivery_Detail_Quantity', required => 1, automated => 'hidden_field' },
                { name => 'Bin_Delivery_Detail_Containers', required => 1, automated => 'hidden_field' },
                { name => 'Bin_Delivery_Detail_Container', required => 1, automated => 'hidden_field' },
                { name => 'current_containers', required => 1, automated => 'hidden_field' },
                { name => 'new_containers', required => 1, automated => 'hidden_field' },
                { name => 'payment_method', required => 1, automated => 'hidden_field' },
                { name => 'pro_rata', required => 0, automated => 'hidden_field' },
                { name => 'payment', required => 1, automated => 'hidden_field' },
                { name => 'client_reference', required => 1, automated => 'hidden_field' },
        );
        $contact->update;

        my $sub_for_renewal = setup_dd_test_report({
            'Request_Type' => 1,
            'Subscription_Details_Quantity' => 1,
            'payment_method' => 'direct_debit',
            'property_id' => '54321',
            'uprn' => '654322',
        });

        $id_replacements->{SUB_FOR_RENEWAL} = $sub_for_renewal->id;

        my $sub_for_cancel = setup_dd_test_report({
            'Request_Type' => 1,
            'Subscription_Details_Quantity' => 1,
            'payment_method' => 'direct_debit',
            'property_id' => '54322',
            'uprn' => '654323',
        });

        $id_replacements->{SUB_FOR_CANCEL} = $sub_for_cancel->id;

        # e.g if they tried to create a DD but the process failed
        my $failed_new_sub = setup_dd_test_report({
            'Request_Type' => 1,
            'Subscription_Details_Quantity' => 1,
            'payment_method' => 'direct_debit',
            'property_id' => '54323',
            'uprn' => '654321',
        });
        $failed_new_sub->state('unconfirmed');
        $failed_new_sub->created(\" created - interval '2' second");
        $failed_new_sub->update;

        $id_replacements->{FAILED_NEW_SUB} = $failed_new_sub->id;

        my $new_sub = setup_dd_test_report({
            'Request_Type' => 1,
            'Subscription_Details_Quantity' => 1,
            'payment_method' => 'direct_debit',
            'property_id' => '54323',
            'uprn' => '654321',
        });
        $new_sub->state('unconfirmed');
        $new_sub->update;

        $id_replacements->{NEW_SUB} = $new_sub->id;

        my $renewal_from_cc_sub = setup_dd_test_report({
            'Request_Type' => 2,
            'Subscription_Details_Quantity' => 1,
            'payment_method' => 'direct_debit',
            'property_id' => '154323',
            'uprn' => '1654321',
        });
        $renewal_from_cc_sub->state('unconfirmed');
        $renewal_from_cc_sub->set_extra_metadata('payerReference' => 'RBK1654321');
        $renewal_from_cc_sub->update;

        $id_replacements->{RENEWAL_FROM_CC_SUB} = $renewal_from_cc_sub->id;

        my $sub_for_subsequent_renewal_from_cc_sub = setup_dd_test_report({
            'Request_Type' => 2,
            'Subscription_Details_Quantity' => 1,
            'payment_method' => 'direct_debit',
            'property_id' => '154323',
            'uprn' => '3654321',
        });
        $sub_for_subsequent_renewal_from_cc_sub->set_extra_metadata('payerReference' => 'RBK3654321');
        $sub_for_subsequent_renewal_from_cc_sub->update;

        $id_replacements->{SUB_FOR_SUBSEQUENT_RENEWAL_FROM_CC_SUB} = $sub_for_subsequent_renewal_from_cc_sub->id;

        my $sub_for_unprocessed_cancel = setup_dd_test_report({
            'Request_Type' => 1,
            'Subscription_Details_Quantity' => 1,
            'payment_method' => 'direct_debit',
            'property_id' => '84324',
            'uprn' => '854325',
        });
        $id_replacements->{SUB_FOR_UNPROCESSED_CANCEL} = $sub_for_unprocessed_cancel->id;
        my $unprocessed_cancel = setup_dd_test_report({
            'payment_method' => 'direct_debit',
            'property_id' => '84324',
            'uprn' => '854325',
        });
        $unprocessed_cancel->state('unconfirmed');
        $unprocessed_cancel->category('Cancel Garden Subscription');
        $unprocessed_cancel->set_extra_metadata('payerReference' => get_reference("RBK-SUB_FOR_UNPROCESSED_CANCEL-854325", $id_replacements));
        $unprocessed_cancel->update;

        my $sub_for_processed_cancel = setup_dd_test_report({
            'Request_Type' => 1,
            'Subscription_Details_Quantity' => 1,
            'payment_method' => 'direct_debit',
            'property_id' => '54324',
            'uprn' => '654324',
        });
        my $processed_renewal = setup_dd_test_report({
            'Request_Type' => 2,
            'Subscription_Details_Quantity' => 1,
            'payment_method' => 'direct_debit',
            'property_id' => '54324',
            'uprn' => '654324',
        });
        $processed_renewal->set_extra_metadata('dd_date' => '2021-03-16T00:00:00.000');
        $processed_renewal->update;
        $id_replacements->{PROCESSED_RENEWAL} = $processed_renewal->id;

        my $renewal_nothing_in_echo = setup_dd_test_report({
            'Request_Type' => 1,
            'Subscription_Details_Quantity' => 1,
            'payment_method' => 'direct_debit',
            'property_id' => '74321',
            'uprn' => '754322',
        });
        $id_replacements->{RENEWAL_NOTHING_IN_ECHO} = $renewal_nothing_in_echo->id;

        my $sub_for_cancel_nothing_in_echo = setup_dd_test_report({
            'Request_Type' => 1,
            'Subscription_Details_Quantity' => 1,
            'payment_method' => 'direct_debit',
            'property_id' => '94324',
            'uprn' => '954324',
        });
        $id_replacements->{SUB_CANCEL_NOTHING_IN_ECHO} = $sub_for_cancel_nothing_in_echo->id;

        my $cancel_nothing_in_echo = setup_dd_test_report({
            'payment_method' => 'direct_debit',
            'property_id' => '94324',
            'uprn' => '954324',
        });
        $cancel_nothing_in_echo->state('unconfirmed');
        $cancel_nothing_in_echo->category('Cancel Garden Subscription');
        $cancel_nothing_in_echo->set_extra_metadata('payerReference',  get_reference("RBK-SUB_CANCEL_NOTHING_IN_ECHO-954324", $id_replacements));
        $cancel_nothing_in_echo->update;
        $id_replacements->{CANCEL_NOTHING_IN_ECHO} = $cancel_nothing_in_echo->id;

        my $hidden_ref = "RBK-$id_replacements->{HIDDEN}-554399";
        my $renewal_nothing_ref = "RBK-$id_replacements->{RENEWAL_NOTHING_IN_ECHO}-754322";
        my $skipped_ref = "RBK-$id_replacements->{AD_HOC_SKIPPED}-954325";
        my $warnings = [
            "\n",
            "looking at payment $hidden_ref\n",
            "payment date: 2021-03-16T00:00:00.000\n",
            "category: Garden Subscription (1)\n",
            "extra query is {payerReference: $hidden_ref\n",
            "is a new/ad hoc\n",
            "looking at potential match $id_replacements->{HIDDEN}\n",
            "potential match is a dd payment\n",
            "potential match type is 1\n",
            "found matching report $id_replacements->{HIDDEN} with state hidden\n",
            "no matching record found for Garden Subscription payment with id $hidden_ref\n",
            "done looking at payment $hidden_ref\n",
            "\n",
            "looking at payment $renewal_nothing_ref\n",
            "payment date: 2021-03-16T00:00:00.000\n",
            "category: Garden Subscription (2)\n",
            "extra query is {payerReference: $renewal_nothing_ref\n",
            "is a renewal\n",
            "looking at potential match $id_replacements->{RENEWAL_NOTHING_IN_ECHO} with state confirmed\n",
            "is a matching new report\n",
            "no matching service to renew for $renewal_nothing_ref\n",
            "\n",
            "looking at payment $skipped_ref\n",
            "payment date: 2021-03-16T00:00:00.000\n",
            "category: Garden Subscription (1)\n",
            "extra query is {payerReference: $skipped_ref\n",
            "is a new/ad hoc\n",
            "looking at potential match $id_replacements->{AD_HOC_SKIPPED}\n",
            "potential match is a dd payment\n",
            "potential match type is 3\n",
            "no matching record found for Garden Subscription payment with id $skipped_ref\n",
            "done looking at payment $skipped_ref\n",
        ];
        my $c = FixMyStreet::Cobrand::Kingston->new;
        warnings_are {
            $c->waste_reconcile_direct_debits;
        } $warnings, "warns if no matching record";

        $new_sub->discard_changes;
        is $new_sub->state, 'confirmed', "New report confirmed";
        is $new_sub->get_extra_metadata('payerReference'), get_reference("RBK-NEW_SUB-654321", $id_replacements), "payer reference set";
        is $new_sub->get_extra_field_value('PaymentCode'), get_reference("RBK-NEW_SUB-654321", $id_replacements), 'correct echo payment code field';
        is $new_sub->get_extra_field_value('LastPayMethod'), 3, 'correct echo payment method field';

        $renewal_from_cc_sub->discard_changes;
        is $renewal_from_cc_sub->state, 'confirmed', "Renewal report confirmed";
        is $renewal_from_cc_sub->get_extra_field_value('PaymentCode'), get_reference("RBK-RENEWAL_FROM_CC_SUB-1654321", $id_replacements), 'correct echo payment code field';
        is $renewal_from_cc_sub->get_extra_field_value('Request_Type'), 2, 'From CC Renewal has correct type';
        is $renewal_from_cc_sub->get_extra_field_value('Subscription_Details_Containers'), 26, 'From CC Renewal has correct container type';
        is $renewal_from_cc_sub->get_extra_field_value('service_id'), 2247, 'Renewal has correct service id';
        is $renewal_from_cc_sub->get_extra_field_value('LastPayMethod'), 3, 'correct echo payment method field';

        my $subsequent_renewal_from_cc_sub = FixMyStreet::DB->resultset('Problem')->search({
                extra => { '@>' => encode_json({ "_fields" => [ { name => "uprn", value => '3654321' } ] }) }
            },
            {
                order_by => { -desc => 'id' }
            }
        );
        is $subsequent_renewal_from_cc_sub->count, 2, "two record for subsequent renewal property";
        $subsequent_renewal_from_cc_sub = $subsequent_renewal_from_cc_sub->first;
        is $subsequent_renewal_from_cc_sub->state, 'confirmed', "Renewal report confirmed";
        is $subsequent_renewal_from_cc_sub->get_extra_field_value('PaymentCode'), get_reference("RBK-SUB_FOR_SUBSEQUENT_RENEWAL_FROM_CC_SUB-3654321", $id_replacements), 'correct echo payment code field';
        is $subsequent_renewal_from_cc_sub->get_extra_field_value('Request_Type'), 2, 'Subsequent Renewal has correct type';
        is $subsequent_renewal_from_cc_sub->get_extra_field_value('Subscription_Details_Containers'), 26, 'Subsequent Renewal has correct container type';
        is $subsequent_renewal_from_cc_sub->get_extra_field_value('service_id'), 2247, 'Subsequent Renewal has correct service id';
        is $subsequent_renewal_from_cc_sub->get_extra_field_value('LastPayMethod'), 3, 'correct echo payment method field';
        is $subsequent_renewal_from_cc_sub->get_extra_field_value('payment_method'), 'direct_debit', 'correctly marked as direct debit';

        $ad_hoc_orig->discard_changes;
        is $ad_hoc_orig->get_extra_metadata('dd_date'), "01/01/2021", "dd date unchanged ad hoc orig";

        $ad_hoc->discard_changes;
        is $ad_hoc->state, 'confirmed', "ad hoc report confirmed";
        is $ad_hoc->get_extra_metadata('dd_date'), "2021-03-16T00:00:00.000", "dd date set for ad hoc";
        is $ad_hoc->get_extra_field_value('PaymentCode'), get_reference("RBK-AD_HOC_ORIG-654325", $id_replacements), 'correct echo payment code field';
        is $ad_hoc->get_extra_field_value('LastPayMethod'), 3, 'correct echo payment method field';

        $ad_hoc_skipped->discard_changes;
        is $ad_hoc_skipped->state, 'unconfirmed', "ad hoc report not confirmed";

        $hidden->discard_changes;
        is $hidden->state, 'hidden', "hidden report not confirmed";

        $cc_to_ignore->discard_changes;
        is $cc_to_ignore->state, 'unconfirmed', "cc payment not confirmed";

        $cancel_nothing_in_echo->discard_changes;
        is $cancel_nothing_in_echo->state, 'hidden', 'hide already cancelled report';

        my $renewal = FixMyStreet::DB->resultset('Problem')->search({
                extra => { '@>' => encode_json({ "_fields" => [ { name => "uprn", value => '654322' } ] }) }
            },
            {
                order_by => { -desc => 'id' }
            }
        );

        is $renewal->count, 2, "two records for renewal property";
        my $p = $renewal->first;
        ok $p->id != $sub_for_renewal->id, "not the original record";
        is $p->get_extra_field_value('Request_Type'), 2, "renewal has correct type";
        is $p->get_extra_field_value('Subscription_Details_Quantity'), 2, "renewal has correct number of bins";
        is $p->get_extra_field_value('Request_Type'), 2, "renewal has correct type";
        is $p->get_extra_field_value('Subscription_Details_Containers'), 26, 'renewal has correct container type';
        is $p->get_extra_field_value('service_id'), 2247, 'renewal has correct service id';
        is $p->get_extra_field_value('LastPayMethod'), 3, 'correct echo payment method field';
        is $p->areas, ',2482,8141,';
        is $p->state, 'confirmed';

        my $renewal_too_recent = FixMyStreet::DB->resultset('Problem')->search({
                extra => { '@>' => encode_json({ "_fields" => [ { name => "uprn", value => '654329' } ] }) }
            },
            {
                order_by => { -desc => 'id' }
            }
        );
        is $renewal_too_recent->count, 0, "ignore payments less that three days old";

        my $cancel = FixMyStreet::DB->resultset('Problem')->search({
                extra => { '@>' => encode_json({ "_fields" => [ { name => "uprn", value => '654323' } ] }) },
            }, { order_by => { -desc => 'id' } });
        is $cancel->count, 1, "one record for cancel property";
        is $cancel->first->id, $sub_for_cancel->id, "only record is the original one, no cancellation report created";

        my $processed = FixMyStreet::DB->resultset('Problem')->search({
                extra => { '@>' => encode_json({ "_fields" => [ { name => "uprn", value => '654324' } ] }) }
            },
            {
                order_by => { -desc => 'id' }
            }
        );
        is $processed->count, 2, "two records for processed renewal property";

        my $ad_hoc_processed_rs = FixMyStreet::DB->resultset('Problem')->search({
                extra => { '@>' => encode_json({ "_fields" => [ { name => "uprn", value => '654326' } ] }) }
            },
            {
                order_by => { -desc => 'id' }
            }
        );
        is $ad_hoc_processed_rs->count, 1, "one records for processed ad hoc property";

        $unprocessed_cancel->discard_changes;
        is $unprocessed_cancel->state, 'confirmed', 'Unprocessed cancel is confirmed';
        ok $unprocessed_cancel->confirmed, "confirmed is not null";
        is $unprocessed_cancel->get_extra_metadata('dd_date'), "21/02/2021", "dd date set for unprocessed cancelled";

        $failed_new_sub->discard_changes;
        is $failed_new_sub->state, 'unconfirmed', 'failed sub not confirmed';

        warnings_are {
            $c->waste_reconcile_direct_debits;
        } $warnings, "warns if no matching record";

        $failed_new_sub->discard_changes;
        is $failed_new_sub->state, 'unconfirmed', 'failed sub still unconfirmed on second run';
        $ad_hoc_skipped->discard_changes;
        is $ad_hoc_skipped->state, 'unconfirmed', "ad hoc report not confirmed on second run";

    };
};

my $cb = FixMyStreet::Cobrand::Kingston->new;

for my $test (
    {
        desc => 'basic address',
        data => { results => [ { LPI => {
            PAO_START_NUMBER => 22,
            STREET_DESCRIPTION => "TEST ROAD",
            TOWN_NAME => "TEST TOWN",
            POSTCODE_LOCATOR => "TA1 1AT",
        } } ] },
        address => {
            address1 => "22",
            address2 => "Test Road",
            town => "Test Town",
            postcode => "TA1 1AT",
        }
    },
    {
        desc => 'address with flat',
        data => { results => [ { LPI => {
            SAO_TEXT => "FLAT",
            SAO_START_NUMBER => "1",
            PAO_START_NUMBER => 22,
            STREET_DESCRIPTION => "TEST ROAD",
            TOWN_NAME => "TEST TOWN",
            POSTCODE_LOCATOR => "TA1 1AT",
        } } ] },
        address => {
            address1 => "Flat 1, 22",
            address2 => "Test Road",
            town => "Test Town",
            postcode => "TA1 1AT",
        }
    },
    {
        desc => 'address with name',
        data => { results => [ { LPI => {
            PAO_TEXT => "TEST HOUSE",
            STREET_DESCRIPTION => "TEST ROAD",
            TOWN_NAME => "TEST TOwN",
            POSTCODE_LOCATOR => "TA1 1AT",
        } } ] },
        address => {
            address1 => "Test House",
            address2 => "Test Road",
            town => "Test Town",
            postcode => "TA1 1AT",
        }
    },
    {
        desc => 'address with dependent road',
        data => { results => [ { LPI => {
            PAO_START_NUMBER => "22",
            STREET_DESCRIPTION => "DEPENDENT ROAD, TEST ROAD",
            TOWN_NAME => "TEST TOwN",
            POSTCODE_LOCATOR => "TA1 1AT",
        } } ] },
        address => {
            address1 => "22",
            address2 => "Dependent Road, Test Road",
            town => "Test Town",
            postcode => "TA1 1AT",
        }
    },
    {
        desc => 'name with flat',
        data => { results => [ { LPI => {
            SAO_TEXT => "FLAT",
            SAO_START_NUMBER => "2",
            PAO_TEXT => "TEST HOUSE",
            STREET_DESCRIPTION => "TEST ROAD",
            TOWN_NAME => "TEST TOwN",
            POSTCODE_LOCATOR => "TA1 1AT",
        } } ] },
        address => {
            address1 => "Flat 2, Test House",
            address2 => "Test Road",
            town => "Test Town",
            postcode => "TA1 1AT",
        }
    },
) {
    subtest $test->{desc} => sub {
        is_deeply $cb->get_address_details_from_nlpg($test->{data}), $test->{address}, "correctly parsed address";
    };
}

package SOAP::Result;
sub result { return $_[0]->{result}; }
sub new { my $c = shift; bless { @_ }, $c; }

package main;

subtest 'updating of waste reports' => sub {
    my $integ = Test::MockModule->new('SOAP::Lite');
    $integ->mock(call => sub {
        my ($cls, @args) = @_;
        my $method = $args[0]->name;
        if ($method eq 'GetEvent') {
            my ($key, $type, $value) = ${$args[3]->value}->value;
            my $external_id = ${$value->value}->value->value;
            my ($waste, $event_state_id, $resolution_code) = split /-/, $external_id;
            return SOAP::Result->new(result => {
                Guid => $external_id,
                EventStateId => $event_state_id,
                EventTypeId => '1638',
                LastUpdatedDate => { OffsetMinutes => 60, DateTime => '2020-06-24T14:00:00Z' },
                ResolutionCodeId => $resolution_code,
            });
        } elsif ($method eq 'GetEventType') {
            return SOAP::Result->new(result => {
                Workflow => { States => { State => [
                    { CoreState => 'New', Name => 'New', Id => 15001 },
                    { CoreState => 'Pending', Name => 'Unallocated', Id => 15002 },
                    { CoreState => 'Pending', Name => 'Allocated to Crew', Id => 15003 },
                ] } },
            });
        } else {
            is $method, 'UNKNOWN';
        }
    });

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'kingston',
        COBRAND_FEATURES => {
            echo => { kingston => { url => 'https://www.example.org/' } },
            waste => { kingston => 1 }
        },
    }, sub {
        my @reports = $mech->create_problems_for_body(2, $body->id, 'Garden Subscription', {
            category => 'Garden Subscription',
            cobrand_data => 'waste',
        });
        $reports[1]->update({ external_id => 'something-else' }); # To test loop
        my $report = $reports[0];
        my $cobrand = FixMyStreet::Cobrand::Kingston->new;

        $report->update({ external_id => 'waste-15001-' });
        stdout_like {
            $cobrand->waste_fetch_events({ verbose => 1 });
        } qr/Fetching data for report/;
        $report->discard_changes;
        is $report->comments->count, 0, 'No new update';
        is $report->state, 'confirmed', 'No state change';

        $report->update({ external_id => 'waste-15002-' });
        stdout_like {
            $cobrand->waste_fetch_events({ verbose => 1 });
        } qr/Updating report to state investigating, Unallocated/;
        $report->discard_changes;
        is $report->comments->count, 1, 'A new update';
        my $update = $report->comments->first;
        is $update->text, 'Unallocated';
        is $report->state, 'investigating', 'A state change';

        $report->update({ external_id => 'waste-15003-' });
        stdout_like {
            $cobrand->waste_fetch_events({ verbose => 1 });
        } qr/Fetching data for report/;
        $report->discard_changes;
        is $report->comments->count, 1, 'No new update';
        is $report->state, 'investigating', 'State unchanged';
    };
};

sub setup_dd_test_report {
    my $extras = shift;
    my ($report) = $mech->create_problems_for_body( 1, $body->id, 'Test', {
        category => 'Garden Subscription',
        latitude => 51.402092,
        longitude => 0.015783,
        cobrand => 'kingston',
        cobrand_data => 'waste',
        areas => ',2482,',
        user => $user,
    });

    $extras->{service_id} ||= 2247;
    $extras->{Subscription_Details_Containers} ||= 26;

    my @extras = map { { name => $_, value => $extras->{$_} } } keys %$extras;
    $report->set_extra_fields( @extras );
    $report->update;

    return $report;
}

sub get_reference {
    my ($ref, $replacements) = @_;

    my ($key, $uprn) = $ref =~ /RBK-([A-Z_]*)-(\d+)/;

    return $ref unless $key;
    return $ref unless $replacements->{$key};

    return "RBK-" . $replacements->{$key} . "-$uprn";
}


done_testing();
