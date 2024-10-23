use Test::More;
use Test::MockObject;
use Test::MockModule;
use Test::Exception;
use Test::Output;
use Integrations::EvoClaim;
use File::Slurp;
use MIME::Base64;
use JSON::MaybeXS;
use FixMyStreet::TestMech;

my $mech = FixMyStreet::TestMech->new;

my $ua_mock = Test::MockObject->new;

my $successful_response_mock = Test::MockObject->new;
$successful_response_mock->set_always('is_success', 1);
$successful_response_mock->set_always('content', '{"StatusNumber":200,"Status":"OK","Data":{"Item":"example.jpg"}}');

my $unsuccessful_response_mock = Test::MockObject->new;
$unsuccessful_response_mock->set_always('is_success', 0);
$unsuccessful_response_mock->set_always('status_line', '500 Internal Server Error');
$unsuccessful_response_mock->set_always('content', 'An error occurred. Please try again later.');

my $error_response_mock = Test::MockObject->new;
$error_response_mock->set_always('is_success', 0);
$error_response_mock->set_always('code', 400);
$error_response_mock->set_always('status_line', '400 Bad Request');
$error_response_mock->set_always('content', '{"Data": {"Error":[{"Code":"FNOL01","Message":"File Name or File Content are empty or invalid."}]}}');

my $ukc = Test::MockModule->new('FixMyStreet::Cobrand::UKCouncils');
$ukc->mock('_fetch_features', sub {
    my ($self, $cfg, $x, $y) = @_;
    is $y, 213450, 'Correct latitude';
    return [
        {
            properties => {
                site_name => 'RAIN ROAD',
                area_name => 'AYLESBURY',
                feature_ty => '4A',
                site_code => 'Road ID'
            },
            geometry => {
                type => 'LineString',
                coordinates => [ [ $x-2, $y+2 ], [ $x+2, $y+2 ] ],
            }
        },
    ];
});

# Initialize API client
my $client = Integrations::EvoClaim->new(
    base_url => 'https://api.example.com',
    app_id   => 'APPID',
    api_key  => 'APIKEY',
    user_agent => $ua_mock,
    claims_files_directory => 't/integrations/evo_claim_files',
);

my $file_name = 'example.jpg';
my $file_content_base64 = encode_base64("file content goes here");

my $fnol_data = {
    absence_dates                => "2023-04-10",
    absent_work                  => "Yes",
    actions                      => "Called the police",
    address                      => "123 Example St, Example City, EX1 2PL",
    attention_date               => "2023-04-12",
    aware                        => "Yes",
    claimed_before               => "No",
    damage_claim                 => "Vehicle and property damage",
    describe_cause               => "Other driver lost control",
    describe_injuries            => "Whiplash and minor cuts",
    details                      => "Accident happened at the intersection",
    direction                    => "North",
    dob                          => "1990-01-01",
    email                        => 'example@example.com',
    employer_contact             => "Jane Doe",
    fault_fixed                  => "No",
    fault_reported               => "Yes",
    gp_contact                   => "Dr. John Smith",
    in_vehicle                   => "Yes",
    incident_date                => { year => "2023", month => "04", day => "10" },
    incident_number              => "IN-12345",
    incident_time                => "14:30",
    insurer_address              => "321 Insurer St, Insurer City, IN2 3PL",
    latitude                     => 51.81386,
    location                     => "Example City",
    longitude                    => -0.82973,
    medical_attention            => "Yes",
    mileage                      => "30000",
    name                         => "John Doe",
    ni_number                    => "AB123456C",
    occupation                   => "Software Developer",
    ongoing_treatment            => "Yes",
    phone                        => "07123456789",
    photos                       => "",
    property_damage_description  => "",
    property_photos              => "",
    registration                 => "AB12 CDE",
    report_id                    => "RPT-12345",
    report_police                => "Yes",
    speed                        => "30",
    treatment_details            => "Physical therapy",
    tyre_damage                  => "Yes",
    tyre_mileage                 => "15000",
    v5                           => {"files" => "v5.pdf","filenames" => ["v5.pdf"]},
    v5_in_name                   => "Yes",
    vat_reg                      => "123456789",
    vehicle_damage               => "Front bumper and headlights",
    vehicle_photos               => "vehicle_photo.jpg",
    vehicle_receipts             => {"files" => "receipt.pdf","filenames" => ["receipt.pdf"]},
    weather                      => "Sunny",
    what                         => "Collision",
    what_cause                   => "Loss of control",
    what_cause_other             => "",
    where_cause                  => "carriageway",
    witness_details              => "Witness 1: Name, contact information",
    witnesses                    => "Yes"
};

FixMyStreet::override_config {
    MAPIT_URL => 'http://mapit.uk/',
    ALLOWED_COBRANDS => 'buckinghamshire',
}, sub {
    my $bucks = $mech->create_body_ok(2217, 'Buckinghamshire Council', {}, { cobrand => 'buckinghamshire' });
    my $cobrand = $bucks->get_cobrand_handler;

    # Create a new Problem row in the FixMyStreet database
    my ($problem) = $mech->create_problems_for_body(1, $bucks->id, 'Test problem', {
        category => 'Carriageway defect',
        detail => 'Test problem detail',
        name => 'Test User',
        postcode => 'SW1A 1AA',
        cobrand => 'buckinghamshire',
        cobrand_data => 'claim',
        latitude => 51.81386,
        longitude => -0.82973,
    });

    # Add $fnol_data to the problem's extra metadata
    $problem->set_extra_metadata(%$fnol_data);

    $problem->update;

    subtest 'send_claims - successful response' => sub {
        $ua_mock->mock('post', sub { $successful_response_mock });

        my $problems = FixMyStreet::DB->resultset('Problem')->search({ id => $problem->id });
        my $problem_id = $problem->id;

        $client->verbose(1);
        stdout_like { $client->send_claims($problems, $cobrand) } qr/FNOL submitted successfully for problem ID: $problem_id/, 'Check send_claims output';
        $client->verbose(0);

        # Make a list of calls made to the UA mock.
        my @calls;
        while (my ($method, $args) = $ua_mock->next_call()) {
            my %args_hash = @{$args}[2..$#$args];
            push @calls, { method => $method, url => $args->[1], headers => \%args_hash, body => decode_json($args_hash{Content}) };
        }

        is(scalar(@calls), 3, 'Check number of calls made to UA mock');

        # Get the file calls for v5 and vehicle_receipts
        my @file_calls = splice(@calls, 0, 2);

        for my $call (@file_calls) {
            subtest 'file upload ' . $call->{body}->{FileName}, sub {
                is($call->{method}, 'post', 'POST method was called');
                is($call->{url}, 'https://api.example.com/api/SubmitClaimFnolFile', 'POST request URL is correct');
                is($call->{headers}->{'Content-Type'}, 'application/json', 'POST request Content-Type header is correct');
                ok($call->{body}->{FileName}, 'FileName is in request body');
                ok($call->{body}->{FileContent}, 'FileContent is in request body');
            };
        }

        my $fnol_submission_call = pop @calls;
        is($fnol_submission_call->{method}, 'post', 'POST method was called');
        is($fnol_submission_call->{url}, 'https://api.example.com/api/SubmitClaimFnol', 'POST request URL is correct');
        is($fnol_submission_call->{headers}->{'Content-Type'}, 'application/json', 'POST request Content-Type header is correct');

        my @photo_field_names = qw(photos property_photos vehicle_photos);
        my @file_field_names = qw(property_insurance property_invoices v5 vehicle_receipts);

        for my $key (keys %$fnol_data) {
            # Skip photo and file fields
            next if grep { $key eq $_ } (@photo_field_names, @file_field_names);

            if ($key eq 'incident_date') {
                is($fnol_submission_call->{body}->{incident_date}, '2023-04-10', 'Request body contains incident_date');
                next;
            }

            if ($key eq 'where_cause') {
                is($fnol_submission_call->{body}->{where_cause}, 'Road/Carriageway', 'Request body contains where_cause');
                next;
            }

            if ($key eq 'location') {
                is($fnol_submission_call->{body}->{location}, 'Rain Road, Aylesbury', 'Request body contains location');
                next;
            }

            if ($key eq 'report_id') {
                is($fnol_submission_call->{body}->{report_id}, $problem_id, 'Request body contains report_id');
                next;
            }

            is($fnol_submission_call->{body}->{$key}, $fnol_data->{$key}, "Request body contains $key");
        }

        is($fnol_submission_call->{body}->{fault_id}, $fnol_data->{report_id}, 'Request body contains fault_id');
    };

    subtest 'send_claims - invalid JSON in response' => sub {
        $ua_mock->mock('post', sub { $unsuccessful_response_mock });

        my $problems = FixMyStreet::DB->resultset('Problem')->search({ id => $problem->id });

        throws_ok { $client->send_claims($problems, $cobrand) } qr/Error decoding JSON response/, 'send_claims throws exception on invalid JSON response';
    };

    subtest 'send_claims - error response from API' => sub {
        $ua_mock->mock('post', sub { $error_response_mock });

        my $problems = FixMyStreet::DB->resultset('Problem')->search({ id => $problem->id });

        throws_ok { $client->send_claims($problems, $cobrand) } qr/FNOL Error: FNOL01 - File Name or File Content are empty or invalid./, 'send_claims throws exception on error response from API';
    };

    subtest 'send_claims - does nothing if no claims to send' => sub {
        $ua_mock->clear;

        my $empty_rs = FixMyStreet::DB->resultset('Problem')->search({ id => -1 });

        $client->verbose(1);
        stdout_like { $client->send_claims($empty_rs, $cobrand) } qr/No claims to send/, 'send_claims prints message if no claims to send';
        $client->verbose(0);

        is($ua_mock->called('post'), 0);
    };

    subtest "send_claims - ignores problems that aren't claims" => sub {
        $ua_mock->clear;

        my ($problem) = $mech->create_problems_for_body(1, $bucks->id, 'Test problem', {
            category => 'Carriageway defect',
            detail => 'Test problem detail',
            name => 'Test User',
            postcode => 'SW1A 1AA',
            cobrand_data => 'not_claim',
        });

        my $problems = FixMyStreet::DB->resultset('Problem')->search({ id => $problem->id });

        $client->verbose(1);
        my $problem_id = $problem->id;
        stdout_like { $client->send_claims($problems, $cobrand) } qr/Skipping problem ID: $problem_id as it is not a claim/, 'send_claims prints message if problem is not a claim';
        $client->verbose(0);

        is($ua_mock->called('post'), 0);
    };

    subtest "send_claims - claim location is 'Unknown location' if no features are found" => sub {
        $ukc->mock('_fetch_features', sub { [] });
        $ua_mock->mock('post', sub { $successful_response_mock });

        my $problems = FixMyStreet::DB->resultset('Problem')->search({ id => $problem->id });
        my $problem_id = $problem->id;

        $client->verbose(1);
        stdout_like { $client->send_claims($problems, $cobrand) } qr/FNOL submitted successfully for problem ID: $problem_id/, 'Check send_claims output';
        $client->verbose(0);

        # Make a list of calls made to the UA mock.
        my @calls;
        while (my ($method, $args) = $ua_mock->next_call()) {
            my %args_hash = @{$args}[2..$#$args];
            push @calls, { method => $method, url => $args->[1], headers => \%args_hash, body => decode_json($args_hash{Content}) };
        }

        my $fnol_submission_call = pop @calls;
        is($fnol_submission_call->{body}->{location}, 'Unknown location', 'Request body contains location');
    };
};

done_testing();
