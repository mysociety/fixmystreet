use utf8;
use FixMyStreet::TestMech;
use FixMyStreet::Script::Reports;
use Test::MockModule;

use t::Mock::Hackney;
LWP::Protocol::PSGI->register(t::Mock::Hackney->to_psgi_app, host => 'hackney.api');

my $mech = FixMyStreet::TestMech->new;

my $body = $mech->create_body_ok(2508, 'Hackney Council');
my $contact = $mech->create_contact_ok(body => $body, category => 'Noise report', email => 'noise@example.org');
my $user = $mech->create_user_ok('test@example.net', name => 'Normal User', password => 'secret');
my $staff_user = $mech->create_user_ok('staff@example.org', from_body => $body, name => 'Staff User');

my $geo = Test::MockModule->new('FixMyStreet::Geocode');
$geo->mock('string', sub {
    my $s = shift;
    my $ret = [];
    if ($s eq 'A street') {
        $ret = { latitude => 51.549249, longitude => -0.054106, address => 'A street, Hackney' };
    } elsif ($s eq 'A different street') {
        $ret = {
            error => [
                { latitude => 51.549239, longitude => -0.054106, address => 'A different street, Hackney' },
                { latitude => 51.549339, longitude => -0.054933, address => 'A different street, South Hackney' },
            ]
        };
    }
    return $ret;
});

FixMyStreet::override_config {
    ALLOWED_COBRANDS => ['fixmystreet', 'hackney'],
    MAPIT_URL => 'http://mapit.uk/',
}, sub {
    subtest 'Check category not displayed in normal flow' => sub {
        $mech->host('www.fixmystreet.com');
        $mech->get_ok('/report/new?latitude=51.552267&longitude=-0.063316');
        $mech->content_lacks('Noise report');
        $mech->host('hackney.gov.uk');
        $mech->get_ok('/report/new?latitude=51.552267&longitude=-0.063316');
        $mech->content_lacks('Noise report');
    };
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'hackney',
    COBRAND_FEATURES => {
        noise => { hackney => 1 },
        do_not_reply_email => { hackney => 'fms-hackney-DO-NOT-REPLY@hackney-example.com' },
        address_api => { hackney => { key => '123', url => 'http://hackney.api/', pageAttr => 'page_count' } },
        open311_email => { hackney => { noise_residence => 'noise_residential@example.org,other@example.org', noise_business => 'noise_business@example.org' } },
    },
    PHONE_COUNTRY => 'GB',
    MAPIT_URL => 'http://mapit.uk/',
}, sub {
    subtest 'Report new noise, source address known' => sub {
        $mech->get_ok('/noise');
        $mech->submit_form_ok({ button => 'start' });
        $mech->submit_form_ok({ with_fields => { existing => 0 } });
        $mech->submit_form_ok({ with_fields => { name => "Test McTest", email => $user->email, phone => '01234 567890' } });
        $mech->submit_form_ok({ with_fields => { best_time => [['weekday', 'evening'], 1], best_method => 'email' } });
        $mech->submit_form_ok({ with_fields => { postcode => 'B24QA' } });
        $mech->content_contains('Sorry, we did not find any results');
        $mech->submit_form_ok({ with_fields => { postcode => 'L11JD' } });
        $mech->content_contains('Sorry, that postcode appears to lie outside Hackney');
        $mech->submit_form_ok({ with_fields => { postcode => 'SW1A 1AA' } });
        $mech->content_contains('12 Saint Street, Dalston');
        $mech->content_lacks('1 Road Road');
        $mech->submit_form_ok({ with_fields => { address => '100000111' } });
        $mech->submit_form_ok({ with_fields => { kind => 'music' } });
        $mech->submit_form_ok({ with_fields => { where => 'residence', source_location => 'SW1A 1AA'  } });
        $mech->content_contains('24 High Street');
        $mech->submit_form_ok({ with_fields => { source_address => '100000333' } });
        $mech->submit_form_ok({ with_fields => {
            happening_now => 1,
            happening_pattern => 1,
        } });
        $mech->submit_form_ok({ with_fields => {
            happening_days => [['monday', 'thursday'], 1],
            happening_time => [['morning','evening'], 1],
        } });
        $mech->submit_form_ok({ with_fields => { more_details => 'Details' } });
        $mech->content_contains('What days does the noise');
        $mech->content_lacks('When has the noise occurred');
        $mech->content_contains('Monday');
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('Thank you for reporting this issue');
        FixMyStreet::Script::Reports::send();
        my @emails = $mech->get_email;
        is $emails[0]->header('To'), '"Hackney Council" <noise_residential@example.org>, "Hackney Council" <other@example.org>';
        is $emails[0]->header('Subject'), 'Noise report: 24 High Street, SW1A 1AA';
        is $emails[1]->header('To'), $user->email;
        my $body = $mech->get_text_body_from_email($emails[1]);
        like $body, qr/Your report to Hackney Council has been logged/;
        is $user->alerts->count, 1;
        my $report = $user->problems->first;
        is $report->title, "24 High Street, SW1A 1AA";
        is $report->detail, "Reporter address: 12 Saint Street, Dalston, SW1A 1AA (100000111)\nReporter availability: Weekday or evening, by email\n\nKind of noise: Music\nNoise details: Details\n\nWhere is the noise coming from? A house, flat, park or street\n\nNoise source: 24 High Street, SW1A 1AA (100000333)\n\nIs the noise happening now? Yes\nDoes the time of the noise follow a pattern? Yes\nWhat days does the noise happen? Monday, Thursday\nWhat time does the noise happen? Morning, Evening\n";
        is $report->latitude, 53;
        $mech->clear_emails_ok;
    };
    subtest 'Report new noise, no pattern to times' => sub {
        $mech->get_ok('/noise');
        $mech->submit_form_ok({ button => 'start' });
        $mech->submit_form_ok({ with_fields => { existing => 0 } });
        $mech->submit_form_ok({ with_fields => { name => "Test McTest", email => $user->email, phone => '01234 567890' } });
        $mech->submit_form_ok({ with_fields => { best_time => [['weekday', 'evening'], 1], best_method => 'email' } });
        $mech->submit_form_ok({ with_fields => { postcode => 'SW1A 1AA' } });
        $mech->content_contains('12 Saint Street, Dalston');
        $mech->content_lacks('1 Road Road');
        $mech->submit_form_ok({ with_fields => { address => '100000111' } });
        $mech->submit_form_ok({ with_fields => { kind => 'other', kind_other => 'Other kind' } });
        $mech->submit_form_ok({ with_fields => { where => 'residence', estates => 'no', source_location => 'SW1 1AA' } });
        $mech->content_contains('24 High Street');
        $mech->submit_form_ok({ with_fields => { source_address => '100000333' } });
        $mech->submit_form_ok({ with_fields => {
            happening_now => 0,
            happening_pattern => 0,
        } });
        $mech->submit_form_ok({ with_fields => {
            happening_description => 'late at night',
        } });
        $mech->submit_form_ok({ with_fields => { more_details => 'Details' } });
        $mech->content_lacks('What days does the noise');
        $mech->content_contains('When has the noise occurred');
        $mech->content_contains('late at night');
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('Thank you for reporting this issue');
        FixMyStreet::Script::Reports::send();
        my @emails = $mech->get_email;
        is $emails[0]->header('To'), '"Hackney Council" <noise_residential@example.org>, "Hackney Council" <other@example.org>';
        is $emails[1]->header('To'), $user->email;
        my $body = $mech->get_text_body_from_email($emails[1]);
        like $body, qr/Your report to Hackney Council has been logged/;
        is $user->alerts->count, 2;
        my @reports = $user->problems->search(undef, { order_by => 'id' })->all;
        my $report = $reports[-1];
        is $report->title, "24 High Street, SW1A 1AA";
        is $report->detail, "Reporter address: 12 Saint Street, Dalston, SW1A 1AA (100000111)\nReporter availability: Weekday or evening, by email\n\nKind of noise: Other (Other kind)\nNoise details: Details\n\nWhere is the noise coming from? A house, flat, park or street\nIs the residence a Hackney Estates property? No\nNoise source: 24 High Street, SW1A 1AA (100000333)\n\nIs the noise happening now? No\nDoes the time of the noise follow a pattern? No\nWhen has the noise occurred? late at night\n";
        is $report->latitude, 53;
        $mech->clear_emails_ok;
    };
    subtest 'Report new noise, your address missing, source address not a postcode' => sub {
        $mech->get_ok('/noise');
        $mech->submit_form_ok({ button => 'start' });
        $mech->submit_form_ok({ with_fields => { existing => 0 } });
        $mech->submit_form_ok({ with_fields => { name => "Test McTest", email => $user->email, phone => '01234 567890' } });
        $mech->submit_form_ok({ with_fields => { best_time => [['weekday', 'evening'], 1], best_method => 'email' } });
        $mech->submit_form_ok({ with_fields => { postcode => 'SW1A 1AA' } });
        $mech->submit_form_ok({ with_fields => { address => 'missing' } });
        $mech->submit_form_ok({ with_fields => { address_manual => 'My Address' } });
        $mech->submit_form_ok({ with_fields => { kind => 'diy' } });
        $mech->submit_form_ok({ with_fields => { where => 'residence', source_location => 'A street' } });
        $mech->submit_form_ok({ with_fields => { latitude => 51.549239, longitude => -0.054106, radius => 'medium' } });
        $mech->submit_form_ok({ with_fields => {
            happening_now => 0,
            happening_pattern => 1,
        } });
        $mech->submit_form_ok({ with_fields => {
            happening_days => [['tuesday'], 1],
            happening_time => [['morning','evening'], 1],
        } });
        $mech->submit_form_ok({ with_fields => { more_details => 'Details' } });
        # Check going back skips the geocoding step
        $mech->submit_form_ok({ form_number => 3, fields => { goto => 'where' } });
        $mech->submit_form_ok({ with_fields => { where => 'residence', source_location => 'A different street' } });
        $mech->content_contains('South Hackney');
        $mech->submit_form_ok({ with_fields => { location_matches => '51.549239,-0.054106' } });
        $mech->content_contains('"51.5');
        $mech->submit_form_ok({ with_fields => { latitude => 51.549249, longitude => -0.054106, radius => 'medium' } });
        $mech->submit_form_ok({ with_fields => {
            happening_now => 0,
            happening_pattern => 1,
        } });
        $mech->submit_form_ok({ with_fields => {
            happening_days => [['tuesday'], 1],
            happening_time => [['morning','evening'], 1],
        } });
        $mech->submit_form_ok({ with_fields => { more_details => 'Details' } });
        $mech->content_contains('My Address');
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('Thank you for reporting this issue');
    };
    subtest 'Report new noise, your address missing, source address multiple matches' => sub {
        $mech->get_ok('/noise');
        $mech->submit_form_ok({ button => 'start' });
        $mech->submit_form_ok({ with_fields => { existing => 0 } });
        $mech->submit_form_ok({ with_fields => { name => "Test McTest", email => $user->email, phone => '01234 567890' } });
        $mech->submit_form_ok({ with_fields => { best_time => [['weekday', 'evening'], 1], best_method => 'email' } });
        $mech->submit_form_ok({ with_fields => { postcode => 'SW1A 1AA' } });
        $mech->submit_form_ok({ with_fields => { address => 'missing' } });
        $mech->submit_form_ok({ with_fields => { address_manual => 'My Address' } });
        $mech->submit_form_ok({ with_fields => { kind => 'diy' } });
        $mech->submit_form_ok({ with_fields => { where => 'residence', source_location => 'A different street' } });
        $mech->content_contains('South Hackney');
        $mech->submit_form_ok({ with_fields => { location_matches => '51.549239,-0.054106' } });
        $mech->submit_form_ok({ with_fields => { latitude => 51.549239, longitude => -0.054106, radius => 'medium' } });
        $mech->submit_form_ok({ with_fields => {
            happening_now => 0,
            happening_pattern => 1,
        } });
        $mech->submit_form_ok({ with_fields => {
            happening_days => [['tuesday'], 1],
            happening_time => [['morning','evening'], 1],
        } });
        $mech->submit_form_ok({ with_fields => { more_details => 'Details' } });
        # Check going back skips the geocoding step
        $mech->submit_form_ok({ form_number => 3, fields => { goto => 'where' } });
        $mech->submit_form_ok({ with_fields => { where => 'residence', source_location => 'A street' } });
        $mech->content_contains('"51.5');
        $mech->submit_form_ok({ with_fields => { latitude => 51.549249, longitude => -0.054106, radius => 'medium' } });
        $mech->submit_form_ok({ with_fields => {
            happening_now => 0,
            happening_pattern => 1,
        } });
        $mech->submit_form_ok({ with_fields => {
            happening_days => [['tuesday'], 1],
            happening_time => [['morning','evening'], 1],
        } });
        $mech->submit_form_ok({ with_fields => { more_details => 'Details' } });
        $mech->content_contains('My Address');
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('Thank you for reporting this issue');
    };
    subtest 'Report another instance on existing report' => sub {
        my $report = $user->problems->first;
        $mech->get_ok('/noise');
        $mech->submit_form_ok({ button => 'start' });
        $mech->submit_form_ok({ with_fields => { existing => 1 } });
        is $mech->uri->path, '/auth';
        $mech->submit_form_ok({ with_fields => { username => $user->email, password_sign_in => 'secret' } });
        $mech->submit_form_ok({ with_fields => { report => $report->id } });
        $mech->submit_form_ok({ with_fields => { kind => 'music' } });
        $mech->submit_form_ok({ with_fields => {
            happening_now => 1,
            happening_pattern => 1,
        } });
        $mech->submit_form_ok({ with_fields => {
            happening_days => [['friday', 'saturday'], 1],
            happening_time => 'night',
        } });
        $mech->submit_form_ok({ with_fields => { more_details => 'Details' } });
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('Your additional report has been submitted');
        my $update = $user->comments->first;
        is $update->text, "Kind of noise: Music\nNoise details: Details\n\nIs the noise happening now? Yes\nDoes the time of the noise follow a pattern? Yes\nWhat days does the noise happen? Friday, Saturday\nWhat time does the noise happen? Night\n";
        like $mech->get_text_body_from_email, qr/Kind of noise: Music/;
    };
    subtest 'Report another instance on existing marked-fixed report' => sub {
        my $report = $user->problems->first;
        $report->update({ state => 'fixed - council' });
        $mech->get_ok('/noise');
        $mech->submit_form_ok({ button => 'start' });
        $mech->submit_form_ok({ with_fields => { existing => 1 } });
        $mech->submit_form_ok({ with_fields => { report => $report->id } });
        $mech->submit_form_ok({ with_fields => { kind => 'music' } });
        $mech->submit_form_ok({ with_fields => {
            happening_now => 1,
            happening_pattern => 1,
        } });
        $mech->submit_form_ok({ with_fields => {
            happening_days => [['friday', 'saturday'], 1],
            happening_time => 'night',
        } });
        $mech->submit_form_ok({ with_fields => { more_details => 'Details' } });
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('Your additional report has been submitted');
        my $update = $user->comments->first;
        $report->discard_changes;
        is $update->problem_state, 'confirmed';
        is $report->state, 'confirmed';
    };
};

done_testing;
