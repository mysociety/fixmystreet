use utf8;
use Test::MockModule;
use Test::MockTime qw(:all);
use FixMyStreet::TestMech;
use FixMyStreet::Script::Reports;
use JSON::MaybeXS;
use Path::Tiny;
use File::Temp 'tempdir';

FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $mock = Test::MockModule->new('FixMyStreet::Cobrand::Peterborough');
$mock->mock('_fetch_features', sub { [] });

my $cobrand = FixMyStreet::Cobrand::Peterborough->new;

my $sample_file = path(__FILE__)->parent->child("sample.jpg");

my $mech = FixMyStreet::TestMech->new;

my $params = {
    send_method => 'Open311',
    api_key => 'KEY',
    endpoint => 'endpoint',
    jurisdiction => 'home',
    can_be_devolved => 1,
};
my $body = $mech->create_body_ok(2566, 'Peterborough City Council', $params, { cobrand => 'peterborough' });
my $user = $mech->create_user_ok('test@example.net', name => 'Normal User');
my $user2 = $mech->create_user_ok('test2@example.net', name => 'Very Normal User');
my $staff = $mech->create_user_ok('staff@example.net', name => 'Staff User', from_body => $body->id);
$staff->user_body_permissions->create({ body => $body, permission_type => 'contribute_as_another_user' });
$staff->user_body_permissions->create({ body => $body, permission_type => 'report_mark_private' });
my $super = $mech->create_user_ok('super@example.net', name => 'Super User', is_superuser => 1);

my $bromley = $mech->create_body_ok(2482, 'Bromley Council', {}, { cobrand => 'bromley' });
my $staff_bromley = $mech->create_user_ok('staff_bromley@example.net', name => 'Bromley Staff User', from_body => $bromley->id);
$staff_bromley->user_body_permissions->create({ body => $bromley, permission_type => 'contribute_as_another_user' });
$staff_bromley->user_body_permissions->create({ body => $bromley, permission_type => 'report_mark_private' });

sub create_contact {
    my ($params, $group, @extra) = @_;
    my $contact = $mech->create_contact_ok(body => $body, %$params, group => [$group]);
    $contact->set_extra_metadata( type => 'waste' );
    $contact->set_extra_fields(
        { code => 'uprn', required => 1, automated => 'hidden_field' },
        @extra,
    );
    $contact->update;
}

create_contact(
    { category => 'Bulky collection', email => 'Bartec-238' },
    'Bulky goods',
    { code => 'ITEM_01', required => 1 },
    { code => 'ITEM_02' },
    { code => 'ITEM_03' },
    { code => 'ITEM_04' },
    { code => 'ITEM_05' },
    { code => 'CHARGEABLE' },
    { code => 'CREW NOTES' },
    { code => 'DATE' },
    { code => 'payment' },
    { code => 'payment_method' },
    { code => 'property_id' },
);
create_contact(
    { category => 'Bulky cancel', email => 'Bartec-545' },
    'Bulky goods',
    { code => 'ORIGINAL_SR_NUMBER', required => 1 },
    { code => 'COMMENTS',           required => 1 },
);

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'peterborough',
    COBRAND_FEATURES => {
        bartec => { peterborough => {
            sample_data => 1,
        } },
        waste => { peterborough => 1 },
    },
}, sub {
    my ($b, $jobs_fsd_get) = shared_bartec_mocks();

    subtest 'Bulky goods not available if feature flag not set' => sub {
        $mech->get_ok('/waste/PE1%203NA:100090215480');
        $mech->content_lacks("Book bulky goods collection");

        $mech->get_ok('/waste/PE1%203NA:100090215480/bulky');
        is $mech->res->code, 200, "got 200";
        is $mech->res->previous->code, 302, "got 302 for redirect";
        is $mech->uri->path, '/waste/PE1%203NA:100090215480', 'redirected to property page';
    };
};

FixMyStreet::override_config {
    MAPIT_URL => 'http://mapit.uk/',
    ALLOWED_COBRANDS => 'peterborough',
    COBRAND_FEATURES => {
        bartec => { peterborough => {
            sample_data => 1,
        } },
        waste => { peterborough => 1 },
        waste_features => { peterborough => {
            bulky_enabled => 1,
            bulky_amend_enabled => 'staff',
            bulky_multiple_bookings => 1,
            bulky_retry_bookings => 1,
            bulky_tandc_link => 'peterborough-bulky-waste-tandc.com'
        } },
        payment_gateway => { peterborough => {
            cc_url => 'https://example.org/scp/',
            scp_fund_code => 2,
            customer_ref => 'ABC12345',
            siteID => 999,
            scpID => 1234567,
            hmac_id => 789,
            hmac => 'bmV2ZXIgZ29ubmEgZ2l2ZSB5b3UgdXAKbmV2ZXIgZ29ubmEgbGV0IHlvdSBkb3duCm5ldmVyIGdvbm5hIHJ1bg==',
        } },
    },
    STAGING_FLAGS => {
        send_reports => 1,
    },
    PHOTO_STORAGE_BACKEND => 'FileSystem',
    PHOTO_STORAGE_OPTIONS => {
        UPLOAD_DIR => tempdir( CLEANUP => 1 ),
    },
}, sub {
    my ($b, $jobs_fsd_get, $fs_get) = shared_bartec_mocks();

    subtest 'No bulky if no black bin collection' => sub {
        $b->mock('Features_Schedules_Get', sub { [] });
        $mech->get_ok('/waste');
        $mech->submit_form_ok({ with_fields => { postcode => 'PE1 3NA' } });
        $mech->submit_form_ok({ with_fields => { address => 'PE1 3NA:100090215480' } });
        $mech->content_lacks('Bulky');
        $b->mock('Features_Schedules_Get', sub { $fs_get });
    };

    subtest 'Bulky Waste on bin days page' => sub {
        my $bin_days_url = 'http://localhost/waste/PE1%203NA:100090215480';

        note 'No pricing at all';
        my $cfg = {};
        $body->set_extra_metadata( wasteworks_config => $cfg );
        $body->update;
        $mech->get_ok($bin_days_url);
        $mech->content_lacks('<strong>One free</strong> collection');
        $mech->content_contains('<strong>From £0.00</strong>');

        note 'Base price defined';
        $cfg = { base_price => '1525' };
        $body->set_extra_metadata( wasteworks_config => $cfg );
        $body->update;
        $mech->get_ok($bin_days_url);
        $mech->content_lacks('<strong>One free</strong> collection');
        $mech->content_contains('<strong>From £15.25</strong>');

        note 'Per item cost:';
        note '    with no items';
        $cfg = {
            %$cfg,
            per_item_costs => 1,
        };
        $body->set_extra_metadata( wasteworks_config => $cfg );
        $body->update;
        $mech->get_ok($bin_days_url);
        $mech->content_lacks('<strong>One free</strong> collection');
        $mech->content_contains('<strong>From £0.00</strong>');

        note '    with a 0-cost item';
        $cfg = {
            %$cfg,
            item_list => [
                { price => 0 },
                { price => 2000 },
            ],
        };
        $body->set_extra_metadata( wasteworks_config => $cfg );
        $body->update;
        $mech->get_ok($bin_days_url);
        $mech->content_lacks('<strong>One free</strong> collection');
        $mech->content_contains('<strong>From £0.00</strong>');

        note '    with a non-0-cost item';
        $cfg = {
            %$cfg,
            item_list => [
                { price => 2000 },
                { price => 1999 },
            ],
        };
        $body->set_extra_metadata( wasteworks_config => $cfg );
        $body->update;
        $mech->get_ok($bin_days_url);
        $mech->content_lacks('<strong>One free</strong> collection');
        $mech->content_contains('<strong>From £19.99</strong>');

        note 'Free collection';
        $cfg = {
            %$cfg,
            free_mode => 1,
        };
        $body->set_extra_metadata( wasteworks_config => $cfg );
        $body->update;
        $mech->get_ok($bin_days_url);
        $mech->content_contains('<strong>One free</strong> collection');
        $mech->content_contains('<strong>From £19.99</strong> Afterwards');
    };

    $body->set_extra_metadata(
        wasteworks_config => {
            base_price => '2350',
            per_item_costs => 0,
            free_mode => '0',
            item_list => [
                {   bartec_id => '1001',
                    category  => 'Audio / Visual Elec. equipment',
                    message   => '',
                    name      => 'Amplifiers',
                    price     => '1001',
                },
                {   bartec_id => '1001',
                    category  => 'Audio / Visual Elec. equipment',
                    message   => '',
                    name      => 'DVD/BR Video players',
                    price     => '2002',
                    max => 1,
                },
                {   bartec_id => '1001',
                    category  => 'Audio / Visual Elec. equipment',
                    message   => '',
                    name      => 'HiFi Stereos',
                    price     => '3003',
                    max => 2,
                },

                {   bartec_id => '1002',
                    category  => 'Baby / Toddler',
                    message   => '',
                    name      => 'Childs bed / cot',
                    price     => '4040',
                },
                {   bartec_id => '1002',
                    category  => 'Baby / Toddler',
                    message   => '',
                    name      => 'High chairs',
                    price     => '5050',
                },

                {   bartec_id => '1003',
                    category  => 'Bedroom',
                    message   => '',
                    name      => 'Chest of drawers',
                    price     => '6060',
                },
                {   bartec_id => '1003',
                    category  => 'Bedroom',
                    message   => 'Please dismantle',
                    name      => 'Wardrobes',
                    price     => '7070',
                },
                {   bartec_id => '1004',
                    category  => 'Bedroom',
                    message   => 'Please place in a clear bag',
                    name      => 'Linen & Bedding',
                    price     => '7070',
                },
            ],
        },
    );
    $body->update;

    my $sent_params;
    my $call_params;
    my $pay = Test::MockModule->new('Integrations::SCP');

    $pay->mock(call => sub {
        my $self = shift;
        my $method = shift;
        $call_params = { @_ };
    });
    $pay->mock(pay => sub {
        my $self = shift;
        $sent_params = shift;
        $pay->original('pay')->($self, $sent_params);
        return {
            transactionState => 'IN_PROGRESS',
            scpReference => '12345',
            invokeResult => {
                status => 'SUCCESS',
                redirectUrl => 'http://example.org/faq'
            }
        };
    });
    $pay->mock(query => sub {
        my $self = shift;
        $sent_params = shift;
        return {
            transactionState => 'COMPLETE',
            paymentResult => {
                status => 'SUCCESS',
                paymentDetails => {
                    authDetails => {
                        authCode              => 112233,
                        continuousAuditNumber => 123,
                    },
                    paymentHeader => {
                        uniqueTranId => 54321
                    }
                }
            }
        };
    });

    my $report;
    subtest 'Bulky goods collection booking' => sub {
        subtest '?type=bulky redirect before any bulky booking made' => sub {
            $mech->get_ok('/waste?type=bulky');
            is $mech->uri, 'http://localhost/waste?type=bulky',
                'No redirect if no address data';
            $mech->content_contains( 'What is your address?',
                'user on address page' );

            $mech->submit_form_ok(
                { with_fields => { postcode => 'PE1 3NA' } } );
            $mech->submit_form_ok(
                { with_fields => { address => 'PE1 3NA:100090215480' } } );
            is $mech->uri,
                'http://localhost/waste/PE1%203NA:100090215480/bulky',
                'Redirected to /bulky if address data';
        };

        subtest 'No commercial bookings' => sub {
            $b->mock('Premises_Detail_Get', sub { { BLPUClassification => { ClassificationCode => 'C001' } } });
            $mech->get_ok('/waste/PE1%203NA:100090215480');
            $mech->content_contains('listed as a commercial premises');
            $mech->content_lacks('Book bulky goods collection');
            $b->mock('Premises_Detail_Get', sub { {} });
        };

        $mech->get_ok('/waste/PE1%203NA:100090215480');
        $mech->content_lacks( 'Cancel booking', 'Cancel option unavailable' );
        $mech->follow_link_ok( { text_regex => qr/Book bulky goods collection/i, }, "follow 'Book bulky...' link" );

        subtest 'Intro page' => sub {
            $mech->content_contains('Book bulky goods collection');
            $mech->content_contains('Before you start your booking');
            $mech->content_contains('a href="peterborough-bulky-waste-tandc.com"');
            $mech->content_contains('You can request up to <strong>five items per collection');
            $mech->content_contains('You can amend the items in your booking up until 3pm the day before the collection is scheduled');
            $mech->content_contains('the day before collection is scheduled are entitled to a refund');
            $mech->content_lacks('The price you pay depends how many items you would like collected:');
            $mech->content_lacks('Up to 4 items');
            $mech->content_lacks('Bookings are final and non refundable');
            $mech->submit_form_ok;
        };

        subtest 'Residency check page' => sub {
            $mech->content_contains('Do you live at the property or are you booking on behalf of the householder?');
            $mech->submit_form_ok({ with_fields => { resident => 'No' } });
            $mech->content_contains('cannot book');
            $mech->back;
            $mech->submit_form_ok({ with_fields => { resident => 'Yes' } });
        };

        subtest 'About you page' => sub {
            $mech->content_contains('About you');
            $mech->content_contains('Aragon Direct Services may contact you to obtain more');
            $mech->submit_form_ok({ with_fields => { name => 'Bob Marge' } });
            $mech->content_contains('Please provide an email address');
            $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email }});
        };

        subtest 'Choose date page' => sub {
            $mech->content_lacks('The list displays the available collection dates for your address');
            $mech->content_contains('Choose date for collection');
            $mech->content_contains('Available dates');
            $mech->content_contains('05 August');
            $mech->content_contains('12 August');
            $mech->content_lacks('19 August'); # Max of 2 dates fetched
            $mech->submit_form_ok(
                {   with_fields =>
                        { chosen_date => '2022-08-12T00:00:00' }
                }
            );
        };

        subtest 'Add items page' => sub {
            $mech->content_contains('Add items for collection');
            $mech->content_contains('Item 1');
            $mech->content_contains('Item 2');
            $mech->content_contains('Item 3');
            $mech->content_contains('Item 4');
            $mech->content_contains('Item 5');
            $mech->content_like(
                qr/<option value="Amplifiers".*>Amplifiers<\/option>/);
            $mech->content_contains('data-extra="{&quot;message&quot;:&quot;Please place in a clear bag&quot;}"');

            $mech->submit_form_ok;
            $mech->content_contains(
                'Please select an item');

            $mech->submit_form_ok(
                {   with_fields => {
                        'item_1' => 'Amplifiers',
                        'item_photo_1' => [ $sample_file, undef, Content_Type => 'image/jpeg' ],
                        'item_2' => 'High chairs',
                        'item_3' => 'Wardrobes',
                    },
                },
            );
        };

        sub test_summary {
            my ($date_dow, $date_day) = @_;
            $mech->content_contains('Request a bulky waste collection');
            $mech->content_lacks('Your bulky waste collection');
            $mech->content_contains('Booking Summary');
            $mech->content_contains('Please read carefully all the details');
            $mech->content_contains('You will be redirected to the council’s card payments provider.');
            $mech->content_like(qr/<p class="govuk-!-margin-bottom-0">.*Amplifiers/s);
            $mech->content_contains('<img class="img-preview is--small" alt="Preview image successfully attached" src="/photo/temp.74e3362283b6ef0c48686fb0e161da4043bbcc97.jpeg">');
            $mech->content_like(qr/<p class="govuk-!-margin-bottom-0">.*High chairs/s);
            $mech->content_like(qr/<p class="govuk-!-margin-bottom-0">.*Wardrobes/s);
            # Extra text for wardrobes
            $mech->content_like(qr/<p class="govuk-!-margin-bottom-0">Please dismantle/s);
            $mech->content_contains('3 items requested for collection');
            $mech->content_contains('you can add up to 2 more items');
            $mech->content_lacks('No image of the location has been attached.');
            $mech->content_contains('£23.50');
            $mech->content_contains("<dd>$date_dow $date_day August 2022</dd>");
            my $day_before = $date_day - 1;
            $mech->content_contains("15:00 on $day_before August 2022");
            $mech->content_lacks('Cancel this booking');
            $mech->content_lacks('Show upcoming bin days');
            $mech->content_contains('a href="peterborough-bulky-waste-tandc.com"');
        }
        sub test_summary_submission {
            # external redirects make Test::WWW::Mechanize unhappy so clone
            # the mech for the redirect
            my $mech2 = $mech->clone;
            $mech2->submit_form_ok({ with_fields => { tandc => 1 } });
            is $mech2->res->previous->code, 302, 'payments issues a redirect';
            is $mech2->res->previous->header('Location'), "http://example.org/faq", "redirects to payment gateway";
        }
        sub test_payment_page {
            my $sent_params = shift;

            like $sent_params->{backUrl}, qr/\/waste\/pay_cancel/;
            like $sent_params->{returnUrl}, qr/\/waste\/pay_complete/;

            my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

            is $new_report->category, 'Bulky collection', 'correct category on report';
            is $new_report->title, 'Bulky goods collection', 'correct title on report';
            is $new_report->get_extra_field_value('payment_method'), 'credit_card', 'correct payment method on report';
            is $new_report->state, 'unconfirmed', 'report not confirmed';

            is $sent_params->{items}[0]{amount}, 2350, 'correct amount used';

            $new_report->discard_changes;
            is $new_report->get_extra_metadata('scpReference'), '12345', 'correct scp reference on report';

            return ($token, $new_report, $report_id);
        }

        subtest 'Summary page' => sub { test_summary('Friday', 12) }; # 12th August

        subtest 'Slot has become fully booked' => sub {
            # Slot has become fully booked in the meantime - should
            # redirect to date selection

            # Mock out a bulky workpack with maximum number of jobs
            $b->mock(
                'WorkPacks_Get',
                sub {
                    [   {   'ID'   => '120822',
                            'Name' => 'Waste-BULKY WASTE-120822',
                        },
                    ];
                },
            );
            my $other_uprn = 10001;
            $b->mock( 'Jobs_Get_for_workpack',
                [ map { { Job => { UPRN => $other_uprn++ } } } 1 .. 40 ]
            );

            $mech->submit_form_ok( { with_fields => { tandc => 1 } } );
            $mech->content_contains('Choose date for collection');
            $mech->content_contains(
                'Unfortunately, the slot you originally chose has become fully booked. Please select another date.',
            );
            $mech->content_lacks( '2022-08-12T00:00:00', 'Original date no longer an option' );
        };

        subtest 'New date selected, submit pages again' => sub {
            $mech->submit_form_ok({ with_fields => { chosen_date => '2022-08-26T00:00:00' } });
            $mech->submit_form_ok({ with_fields => { 'item_1' => 'Amplifiers', 'item_2' => 'High chairs', 'item_3' => 'Wardrobes' } });
        };

        subtest 'Summary submission' => \&test_summary_submission;

        subtest 'Payment page' => sub {
            my ($token, $new_report, $report_id) = test_payment_page($sent_params);
            # Check changing your mind from payment page
            $mech->get_ok("/waste/pay_cancel/$report_id/$token?property_id=PE1%203NA:100090215480");
        };

        subtest 'Summary page' => sub { test_summary('Friday', 26) }; # 26th August
        subtest 'Summary submission again' => \&test_summary_submission;
        subtest 'Payment page again' => sub {
            my ($token, $new_report, $report_id) = test_payment_page($sent_params);

            $mech->get('/waste/pay/xx/yyyyyyyyyyy');
            ok !$mech->res->is_success(), "want a bad response";
            is $mech->res->code, 404, "got 404";
            $mech->get("/waste/pay_complete/$report_id/NOTATOKEN");
            ok !$mech->res->is_success(), "want a bad response";
            is $mech->res->code, 404, "got 404";

            $mech->get_ok("/waste/pay_complete/$report_id/$token");
            is $sent_params->{scpReference}, 12345, 'correct scpReference sent';

            $new_report->discard_changes;
            is $new_report->state, 'confirmed', 'report confirmed';
            is $new_report->get_extra_metadata('payment_reference'), '54321', 'correct payment reference on report';
        };

        subtest 'Confirmation page' => sub {
            $mech->content_contains('Payment successful');

            $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
            is $report->detail, "Address: 1 Pope Way, Peterborough, PE1 3NA";
            is $report->category, 'Bulky collection';
            is $report->title, 'Bulky goods collection';
            is $report->get_extra_field_value('uprn'), 100090215480;
            is $report->get_extra_field_value('DATE'), '2022-08-26T00:00:00';
            is $report->get_extra_field_value('CREW NOTES'), '';
            is $report->get_extra_field_value('CHARGEABLE'), 'CHARGED';
            is $report->get_extra_field_value('ITEM_01'), 'Amplifiers';
            is $report->get_extra_field_value('ITEM_02'), 'High chairs';
            is $report->get_extra_field_value('ITEM_03'), 'Wardrobes';
            is $report->get_extra_field_value('ITEM_04'), '';
            is $report->get_extra_field_value('ITEM_05'), '';
            is $report->get_extra_field_value('property_id'), 'PE1 3NA:100090215480';
            is $report->photo,
                '74e3362283b6ef0c48686fb0e161da4043bbcc97.jpeg';
        };
    };

    # Collection date: 2022-08-26T00:00:00
    # Time/date that is within the cancellation & refund window:
    my $good_date = '2022-08-25T05:44:59Z'; # 06:44:59 UK time
    # Time/date that is within the cancellation but not refund window:
    my $no_refund_date = '2022-08-25T12:00:00Z'; # 13:00:00 UK time
    # Time/date that isn't:
    my $bad_date = '2022-08-25T15:00:00Z';

    subtest 'Bulky goods collection viewing' => sub {
        subtest 'View own booking' => sub {
            # Raise the price to check it hasn't changed on the report page
            my $cfg = $body->get_extra_metadata('wasteworks_config');
            $cfg->{base_price} = 2450;
            $body->set_extra_metadata( wasteworks_config => $cfg );
            $body->update;

            $mech->log_in_ok($user->email);
            $mech->get_ok('/report/' . $report->id);

            $mech->content_contains('Booking Summary');
            $mech->content_contains('1 Pope Way, Peterborough, PE1 3NA');
            $mech->content_lacks('Please read carefully all the details');
            $mech->content_lacks('You will be redirected to the council’s card payments provider.');
            $mech->content_like(qr/<p class="govuk-!-margin-bottom-0">.*Amplifiers/s);
            $mech->content_like(qr/<p class="govuk-!-margin-bottom-0">.*High chairs/s);
            $mech->content_like(qr/<p class="govuk-!-margin-bottom-0">.*Wardrobes/s);
            # Extra text for wardrobes
            $mech->content_like(qr/<p class="govuk-!-margin-bottom-0">Please dismantle/s);
            $mech->content_contains('3 items requested for collection');
            $mech->content_contains('you can add up to 2 more items');
            $mech->content_contains('£23.50');
            $mech->content_contains('Friday 26 August 2022');
            $mech->content_lacks('Request a bulky waste collection');
            $mech->content_contains('Your bulky waste collection');
            $mech->content_contains('Show upcoming bin days');

            $cfg->{base_price} = 2350;
            $body->set_extra_metadata( wasteworks_config => $cfg );
            $body->update;

            # Cancellation messaging & options
            $mech->content_lacks('This collection has been cancelled');
            $mech->content_lacks('View cancellation report');

            set_fixed_time($good_date);
            $mech->get_ok('/report/' . $report->id);
            $mech->content_contains("You can cancel this booking till");
            $mech->content_contains("15:00 on 25 August 2022");

            # Presence of external_id in report implies we have sent request
            # to Bartec
            $mech->content_lacks('/waste/PE1%203NA:100090215480/bulky/cancel/' . $report->id);
            $mech->content_lacks('Cancel this booking');

            $report->external_id('Bartec-SR00100001');
            $report->update;
            $mech->get_ok('/report/' . $report->id);
            $mech->content_contains('/waste/PE1%203NA:100090215480/bulky/cancel/' . $report->id);
            $mech->content_contains('Cancel this booking');

            # Cannot cancel if cancellation window passed
            set_fixed_time($bad_date);
            $mech->get_ok('/report/' . $report->id);
            $mech->content_lacks("You can cancel this booking till");
            $mech->content_lacks("15:00 on 25 August 2022");
            $mech->content_lacks('/waste/PE1%203NA:100090215480/bulky/cancel/' . $report->id);
            $mech->content_lacks('Cancel this booking');

            set_fixed_time($good_date);
        };

        subtest "Can't view booking logged-out" => sub {
            $mech->log_out_ok;
            $mech->get('/report/' . $report->id);

            is $mech->res->code, 403, "got 403";
            $mech->content_contains('Sorry, you don’t have permission to do that.');
        };

        subtest "Can't view someone else's booking" => sub {
            $mech->log_in_ok($user2->email);
            $mech->get('/report/' . $report->id);

            is $mech->res->code, 403, "got 403";
            $mech->content_contains('Sorry, you don’t have permission to do that.');
        };

        subtest "Staff can view booking" => sub {
            $mech->log_in_ok($staff->email);
            $mech->get_ok('/report/' . $report->id);

            $mech->content_contains('Booking Summary');
            $mech->content_contains('Your bulky waste collection');

            # Cancellation messaging & options
            $mech->content_lacks('This collection has been cancelled');
            $mech->content_lacks('View cancellation report');
            $mech->content_contains("You can cancel this booking till");
            $mech->content_contains('/waste/PE1%203NA:100090215480/bulky/cancel/' . $report->id);
            $mech->content_contains('Cancel this booking');
        };

        subtest "Superusers can view booking" => sub {
            $mech->log_in_ok($super->email);
            $mech->get_ok('/report/' . $report->id);

            $mech->content_contains('Booking Summary');
            $mech->content_contains('Your bulky waste collection');

            # Cancellation messaging & options
            $mech->content_lacks('This collection has been cancelled');
            $mech->content_lacks('View cancellation report');
            $mech->content_contains("You can cancel this booking till");
            $mech->content_contains('/waste/PE1%203NA:100090215480/bulky/cancel/' . $report->id);
            $mech->content_contains('Cancel this booking');
        };

        subtest "Can follow link to booking from bin days page" => sub {
            $mech->get_ok('/waste/PE1%203NA:100090215480');
            $mech->follow_link_ok( { text_regex => qr/Check collection details/i, }, "follow 'Check collection...' link" );
            is $mech->uri->path, '/report/' . $report->id , 'Redirected to waste base page';
        };
    };

    # Note 12th August is still stubbed out as unavailable from above
    subtest 'Amending' => sub {

        my $base_path = '/waste/PE1%203NA:100090215480';

        subtest 'Before request sent to Bartec' => sub {
            $report->external_id(undef);
            $report->update;
            $mech->get_ok($base_path);
            $mech->content_lacks('Amend booking');
            $mech->get_ok("$base_path/bulky/amend/" . $report->id);
            is $mech->uri->path, $base_path, 'Amend link redirects to bin days';
        };

        subtest 'After request sent to Bartec' => sub {
            $report->external_id('Bartec-SR00100001');
            $report->update;
            $mech->get_ok($base_path);
            $mech->content_contains('Amend booking');
            $mech->get_ok("$base_path/bulky/amend/" . $report->id);
            is $mech->uri->path, "$base_path/bulky/amend/" . $report->id;
        };

        subtest 'User logged out' => sub {
            $mech->log_out_ok;
            $mech->get_ok($base_path);
            $mech->content_lacks('Amend booking');
            $mech->get_ok("$base_path/bulky/amend/" . $report->id);
            is $mech->uri->path, $base_path;
        };

        subtest 'Other user logged in' => sub {
            $mech->log_in_ok( $user2->email );
            $mech->get_ok($base_path);
            $mech->content_lacks('Amend booking');
            $mech->get_ok("$base_path/bulky/amend/" . $report->id);
            is $mech->uri->path, $base_path, 'Amend link redirects to bin days';
        };

        subtest 'Staff user logged in' => sub {
            $mech->log_in_ok( $staff->email );
            $mech->get_ok($base_path);
            $mech->content_contains('Amend booking');
            $mech->get_ok("$base_path/bulky/amend/" . $report->id);
            is $mech->uri->path, "$base_path/bulky/amend/" . $report->id;
        };

        # Only staff so stay logged in as staff
        $mech->get_ok("$base_path/bulky/amend/" . $report->id);
        $mech->content_contains("Before you amend your booking");
        $mech->submit_form_ok;

        subtest 'Do not change anything' => sub {
            $mech->content_contains('Choose date for collection');
            $mech->content_contains('Available dates');
            $mech->content_contains('26 August'); # Existing date should always be there
            $mech->content_contains('05 August');
            $mech->content_contains('19 August');
            $mech->submit_form_ok({ with_fields => { chosen_date => '2022-08-26T00:00:00' } });
            $mech->content_contains('Add items for collection');
            $mech->content_like(
                qr/<option value="Amplifiers".*>Amplifiers<\/option>/);
            $mech->content_contains('data-extra="{&quot;message&quot;:&quot;Please place in a clear bag&quot;}"');

            $mech->submit_form_ok({
                with_fields => {
                    'item_1' => 'Amplifiers',
                    'item_2' => 'High chairs',
                    'item_3' => 'Wardrobes'
                },
            });

            $mech->content_contains('Booking Summary');
            $mech->content_lacks('You will be redirected to the council’s card payments provider.');
            $mech->content_like(qr/<p class="govuk-!-margin-bottom-0">.*Amplifiers/s);
            $mech->content_contains('<img class="img-preview is--small" alt="Preview image successfully attached" src="/photo/temp.74e3362283b6ef0c48686fb0e161da4043bbcc97.jpeg">');
            $mech->content_contains('High chairs');
            $mech->content_like(qr/<p class="govuk-!-margin-bottom-0">.*Wardrobes/s);
            $mech->content_contains('3 items requested for collection');
            $mech->content_contains('you can add up to 2 more items');
            $mech->content_contains('£23.50');
            $mech->content_contains("<dd>Friday 26 August 2022</dd>");
            $mech->content_contains("15:00 on 25 August 2022");
            $mech->content_lacks('Cancel this booking');
            $mech->content_lacks('Show upcoming bin days');
            $mech->submit_form_ok({ with_fields => { tandc => 1 } });
            $mech->content_contains('You have not changed anything');
        };

        # Start again
        $mech->get_ok("$base_path/bulky/amend/" . $report->id);
        $mech->content_contains("Before you amend your booking");
        $mech->submit_form_ok;
        $mech->content_contains('Choose date for collection');
        $mech->content_contains('Available dates');
        $mech->content_contains('26 August'); # Existing date should always be there
        $mech->content_contains('05 August');
        $mech->content_contains('19 August');
        $mech->submit_form_ok({ with_fields => { chosen_date => '2022-08-26T00:00:00' } });
        $mech->content_contains('Add items for collection');
        $mech->content_like(
            qr/<option value="Amplifiers".*>Amplifiers<\/option>/);
        $mech->content_contains('data-extra="{&quot;message&quot;:&quot;Please place in a clear bag&quot;}"');

        $mech->submit_form_ok({
            with_fields => {
                'item_1' => 'Amplifiers',
                'item_photo_1_fileid' => '', # Photo removed
                'item_2' => 'Wardrobes',
                'item_3' => '',
            },
        });

        $mech->content_contains('Booking Summary');
        $mech->content_lacks('You will be redirected to the council’s card payments provider.');
        $mech->content_like(qr/<p class="govuk-!-margin-bottom-0">.*Amplifiers/s);
        $mech->content_lacks('<img class="img-preview is--small" alt="Preview image successfully attached" src="/photo/temp.74e3362283b6ef0c48686fb0e161da4043bbcc97.jpeg">');
        $mech->content_lacks('High chairs');
        $mech->content_like(qr/<p class="govuk-!-margin-bottom-0">.*Wardrobes/s);
        $mech->content_contains('2 items requested for collection');
        $mech->content_contains('you can add up to 3 more items');
        $mech->content_contains('£23.50');
        $mech->content_contains("<dd>Friday 26 August 2022</dd>");
        $mech->content_contains("15:00 on 25 August 2022");
        $mech->content_lacks('Cancel this booking');
        $mech->content_lacks('Show upcoming bin days');

        $mech->submit_form_ok({ with_fields => { tandc => 1 } });
        $mech->content_contains('Collection booked');

        subtest 'Confirmation page' => sub {

            $report->discard_changes;
            is $report->state, 'confirmed', 'Original report still open';
            like $report->detail, qr/Previously submitted as/, 'Original report detail field updated';
            is $report->category, 'Bulky collection';
            is $report->title, 'Bulky goods collection';
            is $report->get_extra_field_value('uprn'), 100090215480;
            is $report->get_extra_field_value('DATE'), '2022-08-26T00:00:00';
            is $report->get_extra_field_value('CHARGEABLE'), 'CHARGED';
            is $report->get_extra_field_value('ITEM_01'), 'Amplifiers';
            is $report->get_extra_field_value('ITEM_02'), 'Wardrobes';
            is $report->get_extra_field_value('ITEM_03'), '';
            is $report->get_extra_field_value('ITEM_04'), '';
            is $report->get_extra_field_value('ITEM_05'), '';
            is $report->get_extra_field_value('property_id'), 'PE1 3NA:100090215480';
            is $report->photo, '';
        };

        my $cancellation_report;
        subtest 'cancellation report' => sub {
            $cancellation_report
                = FixMyStreet::DB->resultset('Problem')->find(
                    { extra => { '@>' => encode_json({ _fields => [ { name => 'ORIGINAL_SR_NUMBER', value => 'SR00100001' } ] }) } },
                );
            is $cancellation_report->category, 'Bulky cancel',
                'Correct category';
            is $cancellation_report->title,
                'Bulky goods cancellation',
                'Correct title';
            is $cancellation_report->get_extra_field_value(
                'COMMENTS'),
                'Cancellation at user request',
                'Correct extra comment field';
            is $cancellation_report->state, 'confirmed',
                'Report confirmed';
            like $cancellation_report->detail,
                qr/Original report ID: SR00100001 \(WasteWorks ${\$report->id}\)/,
                'Original report ID in detail field';
        };

        subtest 'Viewing original report summary after cancellation' => sub {
            my $path = "/report/" . $report->id;
            $mech->log_in_ok($user->email);
            $mech->get_ok($path);
            $mech->content_lacks('Updates');
            $mech->content_lacks('This collection has been cancelled');
            $mech->log_in_ok($super->email);
            $mech->get_ok($path);
            $mech->content_contains('Updates');
            $mech->content_contains('Previously submitted as');
        };

        subtest 'Check no email sent for amending cancellation report' => sub {
            $report->update({ state => 'hidden' }); # So logged email for actual booking not sent
            FixMyStreet::Script::Reports::send();
            $mech->email_count_is(0); # No email from the cancellation report
            $report->update({ state => 'confirmed' }); # Reset
        };
        $cancellation_report->delete;
    };

    subtest 'Bulky goods email confirmation and reminders' => sub {

        my $report_id = $report->id;
        subtest 'Email confirmation of booking' => sub {
            FixMyStreet::Script::Reports::send();
            my $email = $mech->get_email->as_string;
            like $email, qr/1 Pope Way/;
            like $email, qr/Collection date: Friday 26 August 2022/;
            like $email, qr{rborough.example.org/waste/PE1%203NA%3A100090215480/bulky/cancel/$report_id};
            $mech->clear_emails_ok;
        };

        sub reminder_check {
            my ($day, $time, $days, $report_id) = @_;
            set_fixed_time("2022-08-$day" . "T$time:00:00Z");
            $cobrand->bulky_reminders;
            if ($days) {
                my $email = $mech->get_email->as_string;
                like $email, qr/Friday 26 August 2022/;
                like $email, qr{peterborough.example.org/waste/PE1%203NA%3A100090};
                like $email, qr{215480/bulky/cancel/$report_id};
                if ($days == 3) {
                    like $email, qr/This is a reminder that your collection is in 3 days./;
                } else {
                    like $email, qr/This is a reminder that your collection is tomorrow./;
                }
                $mech->clear_emails_ok;
            } else {
                $mech->email_count_is(0);
            }
        }
        subtest 'Email reminders' => sub {
            reminder_check(22, 10, 0, $report->id);
            reminder_check(23, 10, 3, $report->id);
            reminder_check(23, 11, 0, $report->id);
            reminder_check(24, 10, 0, $report->id);
            reminder_check(25, 10, 1, $report->id);
            reminder_check(25, 11, 0, $report->id);
            reminder_check(26, 10, 0, $report->id);
        };

        $report->discard_changes;
    };

    subtest '?type=bulky redirect after bulky booking made' => sub {
        $mech->get_ok('/waste?type=bulky');
        $mech->content_contains( 'What is your address?',
            'user on address page' );
        $mech->submit_form_ok(
            { with_fields => { postcode => 'PE1 3NA' } } );
        $mech->submit_form_ok(
            { with_fields => { address => 'PE1 3NA:100090215480' } } );
        is $mech->uri->path, '/waste/PE1%203NA:100090215480/bulky', 'Redirected to waste base page';
    };

    # Still logged in as staff
    my $report2;
    subtest 'Make a second booking' => sub {
        $mech->get_ok('/waste/PE1%203NA:100090215480');
        $mech->follow_link_ok( { text_regex => qr/Book bulky goods collection/i, }, "follow 'Book bulky...' link" );

        $mech->submit_form_ok;
        $mech->submit_form_ok({ with_fields => { resident => 'Yes' } });
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email }});
        $mech->content_contains('05 August');
        $mech->content_lacks('12 August'); # Still full from above
        $mech->content_contains('19 August'); # Max of 2 dates fetched
        # Test going later
        $mech->form_number(0)->action($mech->form_number(0)->action . '?later_dates=1');
        $mech->submit_form_ok({ with_fields => { show_later_dates => 1 } });
        $mech->content_like(qr/name="chosen_date" value="2022-08-26T00:00:00"\s+disabled/, 'Already booked date disabled');
        $mech->content_contains('02 September');
        $mech->submit_form_ok({ with_fields => { chosen_date => '2022-09-02T00:00:00' } });
        $mech->submit_form_ok({ with_fields => { 'item_1' => 'Chest of drawers' } });
        $mech->content_contains('Request a bulky waste collection');
        $mech->content_lacks('Your bulky waste collection');
        $mech->content_contains('Booking Summary');
        $mech->content_contains('Please read carefully all the details');
        $mech->content_contains('You will be redirected to the council’s card payments provider.');
        $mech->content_like(qr/<p class="govuk-!-margin-bottom-0">.*Chest of drawers/s);
        $mech->content_contains('1 item requested for collection');
        $mech->content_contains('you can add up to 4 more items');
        $mech->content_contains('£23.50');
        $mech->content_contains("<dd>Friday 02 September 2022</dd>");
        $mech->content_contains("15:00 on 01 September 2022");
        $mech->content_lacks('Cancel this booking');
        $mech->content_lacks('Show upcoming bin days');
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });
        # Staff method of payment here
        $mech->submit_form_ok({ with_fields => { payenet_code => 123456 } });
        $mech->content_contains('Collection booked');

        $report2 = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        is $report2->detail, "Address: 1 Pope Way, Peterborough, PE1 3NA";
        is $report2->category, 'Bulky collection';
        is $report2->title, 'Bulky goods collection';
        is $report2->get_extra_field_value('uprn'), 100090215480;
        is $report2->get_extra_field_value('DATE'), '2022-09-02T00:00:00';
        is $report2->get_extra_field_value('CHARGEABLE'), 'CHARGED';
        is $report2->get_extra_field_value('ITEM_01'), 'Chest of drawers';
        is $report2->get_extra_field_value('property_id'), 'PE1 3NA:100090215480';
    };

    subtest 'Amending second booking to date of first' => sub {
        $report2->update({ external_id => '123' });
        set_fixed_time($good_date);
        $mech->get_ok('/waste/PE1%203NA:100090215480/bulky/amend/' . $report2->id);
        $mech->submit_form_ok;
        $mech->form_number(0)->action($mech->form_number(0)->action . '?later_dates=1');
        $mech->submit_form_ok({ with_fields => { show_later_dates => 1 } });
        $mech->content_like(qr/name="chosen_date" value="2022-08-26T00:00:00"\s+disabled/, 'Already booked date disabled');
        $mech->content_like(qr/name="chosen_date" value="2022-09-02T00:00:00"\s+checked\s+>/, 'Existing booked date not disabled');
        $report2->update({ external_id => undef, send_state => 'sent' });
    };

    subtest 'Cancellation' => sub {
        $report->update({ external_id => undef }); # For cancellation
        set_fixed_time($good_date);
        my $base_path = '/waste/PE1%203NA:100090215480';

        subtest 'Before request sent to Bartec' => sub {
            # Presence of external_id in report implies we have sent request
            # to Bartec
            $report->external_id(undef);
            $report->update;
            $mech->get_ok($base_path);
            $mech->content_lacks(
                'Cancel booking',
                'Cancel option unavailable',
            );
            $mech->get_ok("$base_path/bulky/cancel/" . $report->id);
            is $mech->uri->path, $base_path,
                'Cancel link redirects to bin days';
        };

        subtest 'After request sent to Bartec' => sub {
            $report->external_id('Bartec-SR00100001');
            $report->update;
            $mech->get_ok($base_path);
            $mech->content_contains(
                'Cancel booking',
                'Cancel option available',
            );
            $mech->get_ok("$base_path/bulky/cancel/" . $report->id);
            is $mech->uri->path, "$base_path/bulky/cancel/" . $report->id,
                'Cancel link does not redirect';
        };

        subtest 'User logged out' => sub {
            $mech->log_out_ok;
            $mech->get_ok($base_path);
            $mech->content_lacks(
                'Cancel booking',
                'Cancel option unavailable',
            );
            $mech->get_ok("$base_path/bulky/cancel/" . $report->id);
            like $mech->uri->path, qr/auth/,
                'Cancel link redirects to /auth';
        };

        subtest 'Other user logged in' => sub {
            $mech->log_in_ok( $user2->email );
            $mech->get_ok($base_path);
            $mech->content_lacks(
                'Cancel booking',
                'Cancel option unavailable if booking does not belong to user',
            );
            $mech->get_ok("$base_path/bulky/cancel/" . $report->id);
            is $mech->uri->path, $base_path,
                'Cancel link redirects to bin days';
        };

        subtest 'Staff user logged in' => sub {
            $mech->log_in_ok( $staff->email );
            $mech->get_ok($base_path);
            $mech->content_contains(
                'Cancel booking',
                'Cancel option available',
            );
            $mech->get_ok("$base_path/bulky/cancel/" . $report->id);
            is $mech->uri->path, "$base_path/bulky/cancel/" . $report->id,
                'Cancel link does not redirect';
        };

        $mech->log_in_ok( $user->email );

        set_fixed_time($bad_date);
        $mech->get_ok($base_path);
        $mech->content_lacks( 'bulky/cancel/' . $report->id . '">Cancel booking',
            'Cancel option unavailable if outside cancellation window' );

        set_fixed_time($no_refund_date);
        $mech->get_ok("$base_path/bulky/cancel/" . $report->id);
        $mech->content_lacks("If you cancel this booking you will receive a refund");
        $mech->content_contains("No Refund Will Be Issued");

        $report->update_extra_field({ name => 'CHARGEABLE', value => 'FREE'});
        $report->update;
        $mech->get_ok("$base_path/bulky/cancel/" . $report->id);
        $mech->content_lacks("If you cancel this booking you will receive a refund");
        $mech->content_lacks("No Refund Will Be Issued");
        $report->update_extra_field({ name => 'CHARGEABLE', value => 'CHARGED'});
        $report->update;

        set_fixed_time($good_date);
        $mech->get_ok("$base_path/bulky/cancel/" . $report->id);
        $mech->content_contains("If you cancel this booking you will receive a refund");
        $mech->submit_form_ok( { with_fields => { confirm => 1 } } );
        $mech->content_contains(
            'Your booking has been cancelled',
            'Cancellation confirmation page shown',
        );
        $mech->follow_link_ok( { text => 'Go back home' } );
        is $mech->uri->path, $base_path,
            'Returned to bin days';
        $mech->content_lacks( 'Cancel booking',
            'Cancel option unavailable if already cancelled' );

        my $cancellation_report;
        subtest 'reports' => sub {
            $report->discard_changes;
            is $report->state, 'closed', 'Original report closed';
            like $report->detail, qr/Cancelled at user request/,
                'Original report detail field updated';

            subtest 'cancellation report' => sub {
                $cancellation_report
                    = FixMyStreet::DB->resultset('Problem')->find(
                        { extra => { '@>' => encode_json({ _fields => [ { name => 'ORIGINAL_SR_NUMBER', value => 'SR00100001' } ] }) } },
                    );
                is $cancellation_report->category, 'Bulky cancel',
                    'Correct category';
                is $cancellation_report->title,
                    'Bulky goods cancellation',
                    'Correct title';
                is $cancellation_report->get_extra_field_value(
                    'COMMENTS'),
                    'Cancellation at user request',
                    'Correct extra comment field';
                is $cancellation_report->state, 'confirmed',
                    'Report confirmed';
                like $cancellation_report->detail,
                    qr/Original report ID: SR00100001 \(WasteWorks ${\$report->id}\)/,
                    'Original report ID in detail field';

                # Cancellation of own booking
                my $id = $cancellation_report->id;
                my $path = "/report/$id";

                $mech->log_in_ok($user->email);
                $mech->get($path);
                $mech->content_contains( 'Bulky goods cancellation',
                    'User can view cancellation report' );

                # Superuser
                $mech->log_in_ok($super->email);
                $mech->get_ok($path);
                $mech->content_contains( 'Bulky goods cancellation',
                    'Superuser can view cancellation report' );

                # P'bro staff
                $mech->log_in_ok($staff->email);
                $mech->get_ok($path);
                $mech->content_contains( 'Bulky goods cancellation',
                    'Peterborough staff can view cancellation report' );

                # Other staff
                $mech->log_in_ok($staff_bromley->email);
                $mech->get($path);
                is $mech->res->code, 403,
                    'Staff from other cobrands cannot view cancellation report';

                # Logged out
                $mech->log_out_ok;
                $mech->get($path);
                is $mech->res->code, 403,
                    'Logged out users cannot view cancellation report';

                # Other user
                $mech->log_in_ok($user2->email);
                $mech->get($path);
                is $mech->res->code, 403,
                    'Other logged-in user cannot view cancellation report';
            };
        };

        subtest 'Viewing original report summary after cancellation' => sub {
            my $id   = $report->id;
            my $path = "/report/$id";

            $mech->log_in_ok( $user->email );
            $mech->get_ok($path);
            $mech->content_contains('This collection has been cancelled');
            $mech->content_lacks('View cancellation report');
            $mech->content_lacks("You can cancel this booking till");
            $mech->content_lacks("15:00 on 25 August 2022");
            $mech->content_lacks('Cancel this booking');

            # Superuser
            $mech->log_in_ok( $super->email );
            $mech->get_ok($path);
            $mech->content_contains('This collection has been cancelled');
            $mech->content_contains('View cancellation report');
            $mech->content_lacks("You can cancel this booking till");
            $mech->content_lacks("15:00 on 25 August 2022");
            $mech->content_lacks('Cancel this booking');

            # P'bro staff
            $mech->log_in_ok( $staff->email );
            $mech->get_ok($path);
            $mech->content_contains('This collection has been cancelled');
            $mech->content_contains('View cancellation report');
            $mech->content_lacks("You can cancel this booking till");
            $mech->content_lacks("15:00 on 25 August 2022");
            $mech->content_lacks('Cancel this booking');
        };

        subtest 'cancellation/refund request email' => sub {
            FixMyStreet::Script::Reports::send();
            my @email = $mech->get_email;
            my $email = $email[0];
            my $cancellation = $email[1];

            is $email->header('Subject'),
                'Refund requested for cancelled bulky goods collection SR00100001',
                'Correct subject';
            is $email->header('To'),
                '"Peterborough City Council" <team@example.org>',
                'Correct recipient';

            my $text = $email->as_string;
            like $text, qr/Capita SCP Response: 12345/,
                'Correct SCP response';
            # XXX Not picking up on mocked time
            like $text, qr|Payment Date: \d{2}/\d{2}/\d{2} \d{2}:\d{2}|,
                'Correct date format';
            like $text, qr/CAN: 123/, 'Correct CAN';
            like $text, qr/Auth Code: 112233/, 'Correct auth code';
            like $text, qr/Original Service Request Number: SR00100001/,
                'Correct SR number';

            is $cancellation->header('Subject'), 'Bulky waste cancellation - reference ' . $cancellation_report->id;
            $text = $cancellation->as_string;
            like $text, qr/Your bulky waste collection has been cancelled/;
            unlike $text, qr/The FixMyStreet team/;
        };

        $mech->clear_emails_ok;
        $cancellation_report->delete;
    };

    $report->delete; # So can have another one below

    subtest 'Bulky collection, per item maximum message hidden if no maximums set' => sub {
        my $cfg = $body->get_extra_metadata('wasteworks_config');
        my $orig = $cfg->{item_list};
        $cfg->{item_list} = [
            {   bartec_id => '1001',
                category  => 'Audio / Visual Elec. equipment',
                message   => '',
                name      => 'Amplifiers',
                price     => '1001',
            },
            {   bartec_id => '1002',
                category  => 'Baby / Toddler',
                message   => '',
                name      => 'Childs bed / cot',
                price     => '4040',
            },
            {   bartec_id => '1002',
                category  => 'Baby / Toddler',
                message   => '',
                name      => 'High chairs',
                price     => '5050',
            },

            {   bartec_id => '1003',
                category  => 'Bedroom',
                message   => '',
                name      => 'Chest of drawers',
                price     => '6060',
            },
            {   bartec_id => '1003',
                category  => 'Bedroom',
                message   => 'Please dismantle',
                name      => 'Wardrobes',
                price     => '7070',
            },
        ];
        $body->set_extra_metadata(wasteworks_config => $cfg);
        $body->update;

        $mech->get_ok('/waste/PE1%203NA:100090215480');
        $mech->follow_link_ok( { text_regex => qr/Book bulky goods collection/i, }, "follow 'Book bulky...' link" );
        $mech->submit_form_ok;
        $mech->submit_form_ok({ with_fields => { resident => 'Yes' } });
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email }});
        $mech->submit_form_ok({ with_fields => { chosen_date => '2022-08-26T00:00:00' } });
        $mech->content_lacks("The following types of item have a maximum number that can be collected");

        $cfg->{item_list} = $orig;
        $body->set_extra_metadata(wasteworks_config => $cfg);
        $body->update;
    };

    subtest 'Bulky collection, per item maximum' => sub {
        $mech->get_ok('/waste/PE1%203NA:100090215480');
        $mech->follow_link_ok( { text_regex => qr/Book bulky goods collection/i, }, "follow 'Book bulky...' link" );
        $mech->submit_form_ok;
        $mech->submit_form_ok({ with_fields => { resident => 'Yes' } });
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email }});
        $mech->submit_form_ok({ with_fields => { chosen_date => '2022-08-26T00:00:00' } });
        $mech->content_contains("The following types of item have a maximum number that can be collected");
        $mech->content_contains('HiFi Stereos: 2');
        $mech->submit_form_ok({ with_fields => { 'item_1' => 'HiFi Stereos', 'item_2' => 'HiFi Stereos', item_3 => 'HiFi Stereos' } });
        $mech->content_contains('Too many of item: HiFi Stereos');
    };

    subtest 'Bulky collection, per item payment' => sub {
        $mech->log_in_ok($user->email);
        my $cfg = $body->get_extra_metadata('wasteworks_config');
        $cfg->{per_item_costs} = 1;
        $cfg->{show_location_page} = 'staff';
        $body->set_extra_metadata(wasteworks_config => $cfg);
        $body->update;

        $mech->get_ok('/waste/PE1%203NA:100090215480');
        $mech->follow_link_ok( { text_regex => qr/Book bulky goods collection/i, }, "follow 'Book bulky...' link" );
        $mech->submit_form_ok;
        $mech->submit_form_ok({ with_fields => { resident => 'Yes' } });
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email }});
        $mech->submit_form_ok({ with_fields => { chosen_date => '2022-08-26T00:00:00' } });
        $mech->submit_form_ok({ with_fields => { 'item_1' => 'Amplifiers', 'item_2' => 'High chairs' } });
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });
        my ( $token, $report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

        is $report->get_extra_field_value('payment_method'), 'credit_card';
        is $report->get_extra_field_value('payment'), 1001 + 5050;
        is $report->get_extra_field_value('uprn'), 100090215480;
    };

    subtest 'Bulky collection, payment by staff' => sub {
        $mech->log_in_ok($staff->email);
        $mech->get_ok('/waste/PE1%203NA:100090215480');
        $mech->follow_link_ok( { text_regex => qr/Book bulky goods collection/i, }, "follow 'Book bulky...' link" );
        $mech->submit_form_ok;
        $mech->submit_form_ok({ with_fields => { resident => 'Yes' } });
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email }});
        $mech->submit_form_ok({ with_fields => { chosen_date => '2022-08-26T00:00:00' } });
        $mech->submit_form_ok({ with_fields => { 'item_1' => 'Amplifiers', 'item_2' => 'High chairs' } });
        $mech->content_contains('a href="peterborough-bulky-waste-tandc.com"');
        $mech->content_lacks('Items must be out for collection by', 'Lacks Kingston/Sutton extra text');
        $mech->submit_form_ok({ with_fields => { location => '' } });
        $mech->content_contains('tandc', 'Can have a blank location');
        $mech->back;
        $mech->submit_form_ok({ with_fields => { location => 'in the middle of the drive' } });
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });
        $mech->content_contains("Confirm Booking");
        $mech->content_lacks("Confirm Subscription");

        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;

        subtest 'Retrying failed payments' => sub {
            $mech->submit_form_ok({ with_fields => { payment_failed => 1 } });
            my $id = $report->id;
            $mech->content_contains("<strong>$id</strong> – can be used to retry the payment");
            my $email = $mech->get_text_body_from_email;
            like $email, qr/Provide the reference number $id so you/;

            $mech->get_ok('/waste');
            $mech->submit_form_ok({ with_fields => { continue_id => $id } });
            $mech->submit_form_ok({ form_number => 2 }); # Second change answers, the items
            $mech->submit_form_ok({ with_fields => { 'item_1' => 'Amplifiers', 'item_2' => 'High chairs', 'item_3' => 'Wardrobes' } });
            $mech->submit_form_ok({ with_fields => { location => 'to the side of the drive' } });
            $mech->content_contains('Wardrobes');
            $mech->submit_form_ok({ with_fields => { tandc => 1 } });

            $mech->get_ok('/waste/PE1%203NA:100090215480');
            $mech->follow_link_ok({ text_regex => qr/Retry booking/i, });
            $mech->submit_form_ok({ with_fields => { tandc => 1 } });
        };

        $mech->submit_form_ok({ with_fields => { payenet_code => 123456 } });
        $report->discard_changes;

        is $report->detail, "Address: 1 Pope Way, Peterborough, PE1 3NA";
        is $report->category, 'Bulky collection';
        is $report->title, 'Bulky goods collection';
        is $report->get_extra_field_value('payment_method'), 'csc';
        is $report->get_extra_field_value('uprn'), 100090215480;
        is $report->get_extra_field_value('DATE'), '2022-08-26T00:00:00';
        is $report->get_extra_field_value('CREW NOTES'), 'to the side of the drive';
        is $report->get_extra_field_value('ITEM_01'), 'Amplifiers';
        is $report->get_extra_field_value('ITEM_03'), 'Wardrobes';

        subtest 'Refund email includes PAYE.net code' => sub {
            $report->external_id('Bartec-SR00100001');
            $report->update;

            set_fixed_time('2022-08-25T05:44:59Z');
            $mech->get_ok('/waste/PE1%203NA:100090215480/bulky/cancel/' . $report->id);
            $mech->content_contains("If you cancel this booking you will receive a refund");
            $mech->submit_form_ok( { with_fields => { confirm => 1 } } );
            $mech->content_contains(
                'Your booking has been cancelled',
                'Cancellation confirmation page shown',
            );
            my $email = $mech->get_email;
            my $text = $email->as_string;
            like $text, qr/PAYE.net code: 123456/,
                'Correct PAYE.net code';
            unlike $text, qr/Capita SCP Response:/;
            unlike $text, qr/CAN:/, 'Correct CAN';
            unlike $text, qr/Auth Code:/, 'Correct auth code';
            like $text, qr/Original Service Request Number: SR00100001/,
                'Correct SR number';

            $mech->clear_emails_ok;
            FixMyStreet::DB->resultset('Problem')->find(
                { extra => { '@>' => encode_json({ _fields => [ { name => 'ORIGINAL_SR_NUMBER', value => 'SR00100001' } ] }) } },
            )->delete;
        };

        $mech->log_out_ok;
        $report->delete;
    };

    subtest 'Bulky collection, free' => sub {
        my $cfg = $body->get_extra_metadata('wasteworks_config');
        $cfg->{free_mode} = 1;
        $cfg->{per_item_costs} = 0;
        $body->set_extra_metadata(wasteworks_config => $cfg);
        $body->update;

        $mech->get_ok('/waste/PE1%203NA:100090215480');
        $mech->follow_link_ok( { text_regex => qr/Book bulky goods collection/i, }, "follow 'Book bulky...' link" );
        $mech->submit_form_ok;
        $mech->submit_form_ok({ with_fields => { resident => 'Yes' } });
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email }});
        $mech->submit_form_ok({ with_fields => { chosen_date => '2022-08-26T00:00:00' } });
        $mech->content_like(qr/£<[^>]*>0\.00/);
        $mech->submit_form_ok({ with_fields => { 'item_1' => 'Amplifiers', 'item_2' => 'High chairs' } });
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });

        $mech->content_contains('Your booking is not complete yet');
        my $link = $mech->get_link_from_email;
        $mech->get_ok($link);
        $mech->content_contains('Collection booked');

        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        is $report->detail, "Address: 1 Pope Way, Peterborough, PE1 3NA";
        is $report->category, 'Bulky collection';
        is $report->title, 'Bulky goods collection';
        is $report->get_extra_field_value('payment_method'), '';
        is $report->get_extra_field_value('uprn'), 100090215480;
        is $report->get_extra_field_value('DATE'), '2022-08-26T00:00:00';
        is $report->get_extra_field_value('CHARGEABLE'), 'FREE';

        subtest 'cancel free collection' => sub {
            # Time/date that is within the cancellation & refund window
            set_fixed_time('2022-08-25T05:44:59Z');  # 06:44:59 UK time

            # Presence of external_id in report implies we have sent request
            # to Bartec
            $report->external_id('Bartec-SR00100001');
            $report->update;

            $mech->get_ok('/waste/PE1%203NA:100090215480/bulky/cancel/' . $report->id);
            $mech->submit_form_ok( { with_fields => { confirm => 1 } } );

            # No refund request sent
            $mech->email_count_is(0);

            $report->discard_changes;
            is $report->state, 'closed', 'Original report closed';

            my $cancellation_report
                = FixMyStreet::DB->resultset('Problem')->find(
                    { extra => { '@>' => encode_json({ _fields => [ { name => 'ORIGINAL_SR_NUMBER', value => 'SR00100001' } ] }) } },
            );
            like $cancellation_report->detail,
                qr/Original report ID: SR00100001 \(WasteWorks ${\$report->id}\)/,
                'Original report ID in detail field';
        };

        $mech->log_out_ok;
        $report->delete;
    };

    subtest 'Bulky collection, free already used' => sub {
        # Main config still has free from above

        $b->mock('Premises_Attributes_Get', sub { [
            { AttributeDefinition => { Name => 'FREE BULKY USED' } },
        ] });

        $mech->get_ok('/waste/PE1%203NA:100090215480');
        $mech->follow_link_ok( { text_regex => qr/Book bulky goods collection/i, }, "follow 'Book bulky...' link" );
        $mech->submit_form_ok;
        $mech->submit_form_ok({ with_fields => { resident => 'Yes' } });
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email }});
        $mech->submit_form_ok({ with_fields => { chosen_date => '2022-08-26T00:00:00' } });
        $mech->content_like(qr/£<[^>]*>23\.50/);
        $mech->submit_form_ok({ with_fields => { 'item_1' => 'Amplifiers', 'item_2' => 'High chairs' } });
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });
        my ( $token, $report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

        is $report->get_extra_field_value('payment_method'), 'credit_card';
        is $report->get_extra_field_value('payment'), 2350;
        is $report->get_extra_field_value('uprn'), 100090215480;

        $report->delete;
        $b->mock('Premises_Attributes_Get', sub { [] });

        my $cfg = $body->get_extra_metadata('wasteworks_config');
        $cfg->{free_mode} = 0;
        $cfg->{per_item_costs} = 0;
        $body->set_extra_metadata(wasteworks_config => $cfg);
        $body->update;
    };

};

FixMyStreet::override_config {
    MAPIT_URL => 'http://mapit.uk/',
    ALLOWED_COBRANDS => 'peterborough',
    COBRAND_FEATURES => {
        bartec => { peterborough => { sample_data => 1 } },
        waste => { peterborough => 1 },
        waste_features => { peterborough => {
            bulky_enabled => 1,
            bulky_multiple_bookings => 1,
            bulky_retry_bookings => 0,
            bulky_tandc_link => 'peterborough-bulky-waste-tandc.com'
        } },
    },
}, sub {
    my ($b, $jobs_fsd_get, $fs_get) = shared_bartec_mocks();
    subtest 'Bulky collection, payment by staff, no retrying enabled' => sub {
        $mech->log_in_ok($staff->email);
        $mech->get_ok('/waste/PE1%203NA:100090215480/bulky');
        $mech->submit_form_ok;
        $mech->submit_form_ok({ with_fields => { resident => 'Yes' } });
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email }});
        $mech->submit_form_ok({ with_fields => { chosen_date => '2022-08-26T00:00:00' } });
        $mech->submit_form_ok({ with_fields => { 'item_1' => 'Amplifiers', 'item_2' => 'High chairs' } });
        $mech->submit_form_ok({ with_fields => { location => 'in the middle of the drive' } });
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });
        $mech->submit_form_ok({ with_fields => { payment_failed => 1 } });
        $mech->content_lacks("can be used to retry the payment");

        my $email = $mech->get_text_body_from_email;
        unlike $email, qr/Provide the reference number/;
        $mech->get_ok('/waste');
        $mech->content_lacks('continue_id');
        $mech->get_ok('/waste/PE1%203NA:100090215480');
        $mech->content_lacks('Retry booking');
    };
};

FixMyStreet::override_config {
    MAPIT_URL => 'http://mapit.uk/',
    ALLOWED_COBRANDS => 'peterborough',
    COBRAND_FEATURES => {
        bartec => { peterborough => {
            sample_data => 1,
        } },
        waste => { peterborough => 1 },
        waste_features => { peterborough => {
            bulky_enabled => 'staff',
        } },
    },
}, sub {
    my ($b, $jobs_fsd_get) = shared_bartec_mocks();

    my $bin_days_url = 'http://localhost/waste/PE1%203NA:100090215480';

    subtest 'Logged-out users can’t see bulky goods when set to staff-only' => sub {
        $mech->log_out_ok;

        $mech->get_ok($bin_days_url);
        $mech->content_lacks('Bulky Waste');
    };

    subtest 'Logged-in users can’t see bulky goods when set to staff-only' => sub {
        $mech->log_in_ok($user->email);

        $mech->get_ok($bin_days_url);
        $mech->content_lacks('Bulky Waste');
    };

    subtest 'Logged-in staff can see bulky goods when set to staff-only' => sub {
        $mech->log_in_ok($staff->email);

        $mech->get_ok($bin_days_url);
        $mech->content_contains('Bulky Waste');
    };

    subtest 'Logged-in superusers can see bulky goods when set to staff-only' => sub {
        $mech->log_in_ok($super->email);

        $mech->get_ok($bin_days_url);
        $mech->content_contains('Bulky Waste');
    };
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'peterborough', 'bromley' ],
    COBRAND_FEATURES => {
        bartec => { peterborough => {
            sample_data => 1,
        } },
        waste => {
            peterborough => 1,
            bromley => 1
        },
        waste_features => {
            peterborough => {
                admin_config_enabled => 1,
                bulky_enabled => 1
            }
        }
    },
}, sub {
    subtest 'WasteWorks bulky goods item list administration' => sub {
        ok $mech->host('peterborough.fixmystreet.com');
        my ($b, $jobs_fsd_get) = shared_bartec_mocks();

        subtest 'List admin page is linked from config page' => sub {
            $mech->log_in_ok($super->email);
            $mech->get_ok('/admin/waste/' . $body->id);
            $mech->follow_link_ok( { text_regex => qr/Bulky items list/i, }, "follow 'Bulky items list' link" );
            is $mech->uri->path, '/admin/waste/' . $body->id . '/bulky_items', 'ended up on correct page';
        };

        subtest 'Items can be stored correctly' => sub {
            $body->set_extra_metadata(wasteworks_config => {});
            $body->update;

            # check validation of required fields
            $mech->get_ok('/admin/waste/' . $body->id . '/bulky_items');
            $mech->submit_form_ok({ with_fields => {
                'bartec_id[9999]' => 1234,
                'category[9999]' => 'Furniture',
                'name[9999]' => '', # name is required
                'price[9999]' => '0',
                'message[9999]' => '',
            }});
            $mech->content_lacks("Updated!");
            $mech->content_contains("Please correct the errors below");

            $body->discard_changes;
            is_deeply $body->get_extra_metadata('wasteworks_config'), {};

            # correctly store an item
            $mech->get_ok('/admin/waste/' . $body->id . '/bulky_items');
            $mech->submit_form_ok({ with_fields => {
                'bartec_id[9999]' => 1234,
                'category[9999]' => 'Furniture',
                'name[9999]' => 'Sofa',
                'price[9999]' => '0',
                'message[9999]' => 'test',
            }});
            $mech->content_contains("Updated!");

            $body->discard_changes;
            is_deeply $body->get_extra_metadata('wasteworks_config'), {
                item_list => [ {
                    bartec_id => "1234",
                    category => "Furniture",
                    message => "test",
                    name => "Sofa",
                    max => "",
                    price => "0"
                }]
            };

            # and add a new one
            $mech->submit_form_ok({ with_fields => {
                'bartec_id[9999]' => 4567,
                'category[9999]' => 'Furniture',
                'name[9999]' => 'Armchair',
                'price[9999]' => '10',
                'message[9999]' => '',
            }});

            $body->discard_changes;
            is_deeply $body->get_extra_metadata('wasteworks_config'), {
                item_list => [
                    {
                        bartec_id => "4567",
                        category => "Furniture",
                        message => "",
                        name => "Armchair",
                        max => "",
                        price => "10"
                    },
                    {
                        bartec_id => "1234",
                        category => "Furniture",
                        message => "test",
                        name => "Sofa",
                        max => "",
                        price => "0"
                    },
                ]
            };

            # delete the first item
            $mech->submit_form_ok({
                fields => {
                    "delete" => "0",
                },
                button => "delete",
            });

            $body->discard_changes;
            is_deeply $body->get_extra_metadata('wasteworks_config'), {
                item_list => [
                    {
                        bartec_id => "1234",
                        category => "Furniture",
                        message => "test",
                        name => "Sofa",
                        max => "",
                        price => "0"
                    },
                ]
            };
        };

        subtest 'Bartec feature list is shown correctly' => sub {
            $body->set_extra_metadata(wasteworks_config => {});
            $body->update;

            $b->mock('Features_Types_Get', sub { [
                {
                    Name => "Bookcase",
                    ID => 6941,
                    FeatureClass => {
                        ID => 282
                    },
                },
                {
                    Name => "Dining table",
                    ID => 6917,
                    FeatureClass => {
                        ID => 282
                    },
                },
                {
                    Name => "Dishwasher",
                    ID => 6990,
                    FeatureClass => {
                        ID => 283
                    },
                },
            ] });


            $mech->get_ok('/admin/waste/' . $body->id . '/bulky_items');
            $mech->content_contains('<option value="6941">Bookcase</option>') or diag $mech->content;
            $mech->content_contains('<option value="6917">Dining table</option>');
            $mech->content_contains('<option value="6990">Dishwasher</option>');
            $mech->submit_form_ok({ with_fields => {
                'bartec_id[9999]' => 6941,
                'category[9999]' => 'Furniture',
                'name[9999]' => 'Bookcase',
                'price[9999]' => '0',
                'max[9999]' => '',
                'message[9999]' => '',
            }});
            $mech->content_contains("Updated!");

            $body->discard_changes;
            is_deeply $body->get_extra_metadata('wasteworks_config'), {
                item_list => [ {
                    bartec_id => "6941",
                    category => "Furniture",
                    message => "",
                    name => "Bookcase",
                    max => "",
                    price => "0"
                }]
            };
        };

        subtest 'Feature classes can set in config to limit feature types' => sub {
            $body->set_extra_metadata(wasteworks_config => { bulky_feature_classes => [ 282 ] });
            $body->update;

            $mech->get_ok('/admin/waste/' . $body->id . '/bulky_items');
            $mech->content_contains('<option value="6941">Bookcase</option>') or diag $mech->content;
            $mech->content_contains('<option value="6917">Dining table</option>');
            $mech->content_lacks('<option value="6990">Dishwasher</option>');
        };
    };
};

sub shared_bartec_mocks {
    my $b = Test::MockModule->new('Integrations::Bartec');
    $b->mock('Authenticate', sub {
        { Token => { TokenString => "TOKEN" } }
    });
    $b->mock('Jobs_Get', sub { [
        { WorkPack => { Name => 'Waste-R1-010821' }, Name => 'Empty Bin 240L Black', ScheduledStart => '2021-08-01T07:00:00' },
        { WorkPack => { Name => 'Waste-R1-050821' }, Name => 'Empty Bin Recycling 240l', ScheduledStart => '2021-08-05T07:00:00' },
    ] });
    my $jobs_fsd_get = [
        { JobID => 123, PreviousDate => '2021-08-01T11:11:11Z', NextDate => '2021-08-08T11:11:11Z', JobName => 'Empty Bin 240L Black' },
        { JobID => 456, PreviousDate => '2021-08-05T10:10:10Z', NextDate => '2021-08-19T10:10:10Z', JobName => 'Empty Bin Recycling 240l' },
        { JobID => 789, PreviousDate => '2021-08-06T10:10:10Z', JobName => 'Empty Brown Bin' },
        { JobID => 890, NextDate => '2022-08-06T10:10:10Z', JobName => 'Empty Clinical Waste' },
    ];
    my $fs_get = [
        { JobName => 'Empty Bin 240L Black', Feature => { Status => { Name => "IN SERVICE" }, FeatureType => { ID => 6533 } }, Frequency => 'Every two weeks' },
        { JobName => 'Empty Bin Recycling 240l', Feature => { Status => { Name => "IN SERVICE" }, FeatureType => { ID => 6534 } } },
        { JobName => 'Empty Clinical Waste', Feature => { Status => { Name => "IN SERVICE" }, FeatureType => { ID => 6815 } } },
        { JobName => 'Empty Brown Bin', Feature => { Status => { Name => "PLANNED" }, FeatureType => { ID => 6579 } } },
    ];
    $b->mock('Jobs_FeatureScheduleDates_Get', sub { $jobs_fsd_get });
    $b->mock('Features_Schedules_Get', sub { $fs_get });
    $b->mock('ServiceRequests_Get', sub { [
        # No open requests at present
    ] });
    $b->mock('Premises_Detail_Get', sub { {} });
    $b->mock('Premises_Attributes_Get', sub { [] });
    $b->mock(
        'Premises_AttributeDefinitions_Get',
        sub {
            [
                { Name => 'FREE BULKY USED', ID => 123 },
            ];
        }
    );
    $b->mock( 'Premises_Attributes_Delete', sub { } );
    $b->mock('Premises_Events_Get', sub { [
        # No open events at present
    ] });
    $b->mock('Streets_Events_Get', sub { [
        # No open events at present
    ] });
    $b->mock( 'Premises_FutureWorkpacks_Get', &_future_workpacks );
    $b->mock( 'WorkPacks_Get',                [] );
    $b->mock( 'Jobs_Get_for_workpack',        [] );
    $b->mock('Features_Types_Get', sub { [
        # No feature types at present
    ] });

    return $b, $jobs_fsd_get, $fs_get;
}

sub _future_workpacks {
    [   {   'WorkPackDate' => '2022-08-05T00:00:00',
            'Actions'      => {
                'Action' => [ { 'ActionName' => 'Empty Bin 240L Black' } ],
            },
        },
        {   'WorkPackDate' => '2022-08-12T00:00:00',
            'Actions'      =>
                { 'Action' => { 'ActionName' => 'Empty Black 240l Bin' } },
        },
        {   'WorkPackDate' => '2022-08-19T00:00:00',
            'Actions'      =>
                { 'Action' => { 'ActionName' => 'Empty Bin 240L Black' } },
        },
        {   'WorkPackDate' => '2022-08-26T00:00:00',
            'Actions'      =>
                { 'Action' => { 'ActionName' => 'Empty Bin 240L Black' } },
        },
        {   'WorkPackDate' => '2022-09-02T00:00:00',
            'Actions'      =>
                { 'Action' => { 'ActionName' => 'Empty Bin 240L Black' } },
        },
    ];
}

sub get_report_from_redirect {
    my $url = shift;

    my ($report_id, $token) = ( $url =~ m#/(\d+)/([^/]+)$# );
    my $new_report = FixMyStreet::DB->resultset('Problem')->find( {
            id => $report_id,
    });

    return undef unless $new_report->get_extra_metadata('redirect_id') eq $token;
    return ($token, $new_report, $report_id);
}


done_testing;
