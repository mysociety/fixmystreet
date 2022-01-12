use strict; use warnings;

use Test::More;
use Test::MockModule;
use Test::MockTime ':all';
use Path::Tiny;
use DateTime;
use XML::Simple;
use SOAP::Lite;
use SOAP::Transport::HTTP;
use HTTP::Request::Common;

use Integrations::Pay360;

sub CreatePayment {
    my %args = @_;

    return <<"EOD"
<CreatePaymentResponse>
    <CreatePaymentResult>
        <OverallStatus>true</OverallStatus>
        <AuthStatus>true</AuthStatus>
        <StatusCode>SA</StatusCode>
        <StatusMessage>Payment created successfully</StatusMessage>
    </CreatePaymentResult>
</CreatePaymentResponse>
EOD
}

sub GetPayerPaymentPlanDetails {

return <<"EOD"
<GetPayerPaymentPlanDetailsResponse>
    <GetPayerPaymentPlanDetailsResult>
        <OverallStatus>true</OverallStatus>
        <AuthStatus>true</AuthStatus>
        <StatusCode>SA</StatusCode>
        <StatusMessage>Success: Payer Payment Plan retrieved</StatusMessage>
        <PayerPaymentPlan>
            <ID>1000-2000-3000-4000</ID>
            <PayerReference>REF123456</PayerReference>
            <FirstAmount />
            <LastAmount />
            <RegularAmount>0.00</RegularAmount>
            <IncludeGiftAid>False</IncludeGiftAid>
            <PaymentPlanID>abcde-fghijk-lmnop</PaymentPlanID>
            <FirstPaymentDate />
            <PaymentDay />
            <PaymentMonth />
            <WeekDay />
            <EndType>Until further notice</EndType>
            <EndDate />
            <NumberOfCollections />
        </PayerPaymentPlan>
    </GetPayerPaymentPlanDetailsResult>
</GetPayerPaymentPlanDetailsResponse>
EOD
}

sub UpdatePayerPaymentPlan {
return <<"EOD"
<UpdatePayerPaymentPlanResponse>
    <UpdatePayerPaymentPlanResult>
        <OverallStatus>true</OverallStatus>
        <AuthStatus>true</AuthStatus>
        <StatusCode>SA</StatusCode>
        <StatusMessage>Success: Payer Payment Plan updated successfully</StatusMessage>
    </UpdatePayerPaymentPlanResult>
</UpdatePayerPaymentPlanResponse>
EOD
}

sub GetPaymentHistoryAllPayersWithDates {
return <<"EOD"
<GetPaymentHistoryAllPayersWithDatesResponse
    xmlns="https://www.emandates.co.uk/v3/">
    <GetPaymentHistoryAllPayersWithDatesResult>
        <OverallStatus>true</OverallStatus>
        <AuthStatus>true</AuthStatus>
        <StatusCode>SA</StatusCode>
        <StatusMessage>Success: Payments retrieved</StatusMessage>
        <Payments>
            <PaymentAPI>
                <PayerName>Anthony Other</PayerName>
                <ClientName>London Borough of Bromley</ClientName>
                <PayerReference>REF123456</PayerReference>
                <Amount>10.00</Amount>
                <CollectionDate>26/02/2021</CollectionDate>
                <DueDate>26/02/2021</DueDate>
                <Type>First Time</Type>
                <AlternateKey />
                <Comments>Test payment</Comments>
                <ProductName>Non Frequency</ProductName>
                <PayerAccountNumber>11111111</PayerAccountNumber>
                <PayerSortCode>010101</PayerSortCode>
                <PayerAccountHoldersName>Anthony Other</PayerAccountHoldersName>
                <Status>Paid</Status>
                <YourRef>65432</YourRef>
            </PaymentAPI>
        </Payments>
    </GetPaymentHistoryAllPayersWithDatesResult>
</GetPaymentHistoryAllPayersWithDatesResponse>
EOD
}

sub gen_full_response {
    my ($append) = @_;

    my $xml = <<EOF;
<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
               xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
               xmlns:xsd="http://www.w3.org/2001/XMLSchema">
<soap:Body>$append</soap:Body>
</soap:Envelope>
EOF

    return $xml;
}

my %sent;

my $t = SOAP::Transport::HTTP::Client->new();
my $transport = Test::MockModule->new('SOAP::Transport::HTTP::Client', no_auto => 1);
$transport->mock(send_receive => sub {
        my $self = shift;
        my %args = @_;

        $sent{ $args{action} } = $args{envelope};

        my $action = \&{ $args{action} };
        my $resp = $action->(%args);
        return gen_full_response( $resp );
    }
);

my $integration = Integrations::Pay360->new(
    config => {
        dd_api_url => 'http://localhost/',
        dd_sun => 1234,
        dd_client_id => 'qpio-rstu-vwxy',
        dd_username => 'username',
        dd_password => 'password',
        dd_payment_plan => 'panama!',
    }
);


subtest "check create payment" => sub {
    my $dt = DateTime->new(
        year => 2021,
        month => 02,
        day => 19
    );

    my $res = $integration->one_off_payment({
            payer_reference => 'payer1',
            amount => 9.99,
            date => $dt,
            reference => 12,
            comment => 'more of a question',
    });

    ok $res, 'got response';

    is $res->{StatusCode}, "SA", 'payment created';

    compare_xml($sent{CreatePayment},
        'CreatePayment',
        {
            reference => 'payer1',
            amountString => 9.99,
            dueDateString => '19-02-2021',
            clientSUN => 1234,
            yourRef => 12,
            comments => 'more of a question',
        },
        'create payment sent xml correct'
    );
};

subtest "check amend plan" => sub {
    my $res = $integration->amend_plan({
        payer_reference => 'payer2',
        amount => 9.99,
    });

    ok $res, 'got response';

    compare_xml($sent{GetPayerPaymentPlanDetails},
        'GetPayerPaymentPlanDetails',
        {
            clientSUN => 1234,
            reference => 'payer2',
        },
        'get payer details sent xml correct'
    );

    compare_xml($sent{UpdatePayerPaymentPlan},
        'UpdatePayerPaymentPlan',
        {
            clientSUN => 1234,
            payerPlan =>{
                EndDate => undef,
                PaymentPlanID => 'abcde-fghijk-lmnop',
                NumberOfCollections => undef,
                FirstPaymentDate => undef,
                PaymentMonth => undef,
                WeekDay => undef,
                PaymentDay => undef,
                LastAmount => undef,
                ID => '1000-2000-3000-4000',
                EndType => 'Until further notice',
                IncludeGiftAid => 'False',
                PayerReference => 'REF123456',
                FirstAmount => undef,
                RegularAmount => 9.99,
            },
        },
        'update payer payment plan sent xml correct'
    );
};

subtest "check get payment list" => sub {
    my $dt = DateTime->new(
        year => 2021,
        month => 2,
        day => 19
    );

    my $res = $integration->get_recent_payments({
        start => $dt->clone->add( days => -4 ),
        end => $dt,
    });

    ok $res, 'got response';

    compare_xml($sent{GetPaymentHistoryAllPayersWithDates},
        'GetPaymentHistoryAllPayersWithDates',
        {
            clientSUN => 1234,
            clientID => 'qpio-rstu-vwxy',
            fromDate => '15/02/2021',
            toDate => '19/02/2021',
        },
        'get payments sent xml correct'
    );

    is_deeply $res, [ {
        AlternateKey => "",
        Amount => '10.00',
        ClientName => "London Borough of Bromley",
        CollectionDate => "26/02/2021",
        Comments => "Test payment",
        DueDate => "26/02/2021",
        PayerAccountHoldersName => "Anthony Other",
        PayerAccountNumber => 11111111,
        PayerName => "Anthony Other",
        PayerReference => "REF123456",
        PayerSortCode => "010101",
        ProductName => "Non Frequency",
        Status => "Paid",
        Type => "First Time",
        YourRef => 65432
    } ],
    "correct return from get payment list";
};

sub compare_xml {
    my ($xml, $key, $obj, $msg) = @_;

    my $simple = XML::Simple->new(
        KeyAttr => {},
        SuppressEmpty => undef,
    );
    my $o = $simple->parse_string($xml);
    $o = $o->{Body} ? $o->{Body}->{$key} : $o->{'soap:Body'}->{$key};
    delete $o->{xmlns};

    is_deeply $o, $obj, $msg;
}


done_testing;
