use Test::MockModule;
use Test::MockTime qw(:all);
use FixMyStreet::TestMech;

FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $mech = FixMyStreet::TestMech->new;

my $body = $mech->create_body_ok(2488, 'Brent', { cobrand => 'brent' });

my $contact = $mech->create_contact_ok(body => $body, ( category => 'Request new container', email => 'request@example.org'), group => ['Waste'], extra => { type => 'waste' } );

$contact->set_extra_fields(
    { code => 'uprn', required => 1, automated => 'hidden_field' },
    { code => 'property_id', required => 1, automated => 'hidden_field' },
    { code => 'service_id', required => 0, automated => 'hidden_field' },
    { code => 'Quantity', required => 1, automated => 'hidden_field' },
    { code => 'Container_Type', required => 1, automated => 'hidden_field' },
    { code => 'Action', required => 0, automated => 'hidden_field' },
    { code => 'Reason', required => 0, automated => 'hidden_field' },
);
$contact->update;

my $echo = Test::MockModule->new('Integrations::Echo');
$echo->mock('call', sub { my ($self, $method, @params) = @_; die "Unmocked call: " . $method });
$echo->mock('GetPointAddress', sub {
    return {
        Id => 12345,
        SharedRef => { Value => { anyType => '1000000002' } },
        PointType => 'PointAddress',
        PointAddressType => { Name => 'House' },
        Coordinates => { GeoPoint => { Latitude => 51.55904, Longitude => -0.28168 } },
        Description => '2 Example Street, Brent',
    };
});
$echo->mock('GetServiceUnitsForObject', sub {
    return [ {
        Id => 1003,
        ServiceId => 262,
        ServiceName => 'Domestic Refuse Collection',
        ServiceTasks => { ServiceTask => {
            Id => 403,
            Data => { },
            ServiceTaskSchedules => { ServiceTaskSchedule => {
                ScheduleDescription => 'Domestic refuse',
                StartDate => { DateTime => '2020-01-01T00:00:00Z' },
                EndDate => { DateTime => '2050-01-01T00:00:00Z' },
                NextInstance => {
                    CurrentScheduledDate => { DateTime => '2020-06-03T00:00:00Z' },
                    OriginalScheduledDate => { DateTime => '2020-06-03T00:00:00Z' },
                },
            } },
        } },
    } ];
});
$echo->mock('GetEventsForObject', sub { [] });

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'brent',
    MAPIT_URL => 'http://mapit.uk/',
    COBRAND_FEATURES => {
        echo => { brent => { url => 'http://example.org' } },
        waste => { brent => 1 },
        waste_request_refuse_container_email => { brent => 'brent@example.com'},
     },
}, sub {
    subtest 'Introduction' => sub {
        $mech->get_ok('/waste/12345');
        $mech->content_contains('Request a new container');
        $mech->get_ok('/waste/12345/request');
        $mech->content_contains('General rubbish bin (grey bin)');
        $mech->submit_form_ok;
        $mech->content_contains('2 Example Street, Brent');
        $mech->content_contains('Please complete this form to apply for a new/replacement refuse bin');
        $mech->content_contains('value="Apply for a new/replacement refuse bin"');
    };

    subtest 'Application form validation' => sub {
        $mech->submit_form_ok;
        $mech->content_contains('2 Example Street, Brent');
        $mech->content_contains('What type of property do you live in?');
        $mech->submit_form_ok;
        subtest 'Radio fields all required and default empty' => sub {
            $mech->content_contains('What type of property do you live in? field is required');
            $mech->content_contains('Reason for requesting a refuse bin field is required');
            $mech->content_contains('What size is the current general waste bin? field is required');
        };

    };

    subtest 'Details with approval' => sub {
        for my $fields
            (
                {
                    request_property_type => '2',
                    request_reason_refuse => '3',
                    request_reason_refuse_size => '3',
                    request_property_people => '6',
                    request_property_nappies => '0'
                }
            )
        {
            $mech->submit_form_ok({
                with_fields => $fields
            });

            $mech->content_contains('2 Example Street, Brent');
            $mech->content_contains('Full name');
            $mech->submit_form_ok({
                with_fields => { name => "John O'Groats", email => 'landsend@example.org' }
            });
            $mech->content_contains('Submit container request');
            $mech->content_contains('Container requests');
            $mech->content_contains('Household details');
            $mech->content_contains('About you');
            $mech->submit_form_ok({form_number => 4});
            $mech->content_contains('Your container request has been sent');
            $mech->content_contains('contact you to let you know if your request has been approved');
            $mech->content_lacks('A copy has been sent to your email address');
        };
    };

    subtest 'Check report created' => sub {
        my ($report) = FixMyStreet::DB->resultset('Problem')->search({ category => 'Request new container' });
        is $report->is_hidden, 1;
        is $report->detail, 'Request forwarded to Brent Council by email';
    };

    subtest 'Check email sent' => sub {
        my $email = $mech->get_email;
        is $email->header('subject'), 'Request for a new/replacement refuse bin - 2 Example Street, Brent';
        for my $email ($mech->get_html_body_from_email($email), $mech->get_text_body_from_email($email) ) {
            like $email, qr/Address: 2 Example Street, Brent/, 'Address in email';
            like $email, qr/Name: John O(&#39;|')Groats/, 'Name in email';
            like $email, qr/Email: landsend\@example.org/, 'Email address in email';
            like $email, qr/What type of property do you live in\?: Shared accommodation/, 'Property question in email';
            like $email, qr/How many people live at your property\?: 6 or more/, 'People count question in email';
            like $email, qr/How many children under 4 or children in nappies live at the property\?: 0/, 'Children count question in email';
            like $email, qr/Reason for requesting a refuse bin: More capacity/, 'Reason for refuse bin request in email';
            like $email, qr/How many general waste bins are currently at the property\?: 0/, 'General waste bins count question in email';
            like $email, qr/What size is the current general waste bin\?: N\/A no bin at property/, 'General waste bin size question in email';
        }
        $mech->clear_emails_ok;
    };

    subtest 'Can not request again after recent request' => sub {
        $mech->get_ok('/waste/12345/request');
        $mech->content_contains('General rubbish bin (grey bin)');
        $mech->submit_form_ok;
        $mech->submit_form_ok;
        $mech->content_contains("Your property meets current general waste bin capacity requirements");
    };

    subtest 'Automatically calculated response' => sub {
        my ($report) = FixMyStreet::DB->resultset('Problem')->search({ category => 'Request new container' });
        $report->delete;
        $report->update;
        $mech->get_ok('/waste/12345/request');
        $mech->content_contains('General rubbish bin (grey bin)');
        $mech->submit_form_ok;
        $mech->submit_form_ok;
        for my $fields
            (
                {
                    request_property_type => '1',
                    request_reason_refuse => '3',
                    request_property_people => '5',
                    request_reason_refuse_size => '3',
                    request_property_nappies => '0'
                }
            )
            {
                $mech->submit_form_ok({
                    with_fields => $fields
                });
                $mech->submit_form_ok({
                    with_fields => { name => "John O'Groats", email => 'landsend@example.org' }
                });
                $mech->submit_form_ok({form_number => 4});
                $mech->content_contains('Your property meets current general waste bin capacity requirements');
            };
    };

    subtest 'Check report created' => sub {
        my ($report) = FixMyStreet::DB->resultset('Problem')->search({ category => 'Request new container' });
        is $report->is_hidden, 1;
        is $report->detail, 'Request automatically calculated';
    };

    subtest 'Check email not sent' => sub {
        $mech->email_count_is(0);
    };

};

done_testing;