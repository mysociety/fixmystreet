use CGI::Simple;
use Test::MockModule;
use Test::MockTime qw(:all);
use FixMyStreet::TestMech;
use FixMyStreet::Script::Reports;
use Class::Method::Modifiers;
use Catalyst::Test 'FixMyStreet::App';
use FixMyStreet::Cobrand::Bexley;
use subs (
    *FixMyStreet::Cobrand::Bexley::opening_hours,
    *FixMyStreet::Cobrand::Bexley::non_working_days
);
set_fixed_time('2019-10-16T17:00:00Z'); # Out of hours

my $mech = FixMyStreet::TestMech->new;

my $body = $mech->create_body_ok(2494, 'London Borough of Bexley', {
    send_method => 'Open311', api_key => 'key', 'endpoint' => 'e', 'jurisdiction' => 'j' });

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'bexley' ],
    MAPIT_URL => 'http://mapit.uk/',
    STAGING_FLAGS => { send_reports => 1, skip_checks => 0 },
    COBRAND_FEATURES => {
        open311_email => { bexley => {
            p1 => 'p1@bexley',
            p1confirm => 'p1confirm@bexley',
            lighting => 'thirdparty@notbexley.example.com,another@notbexley.example.com',
            outofhours => 'outofhours@bexley,ooh2@bexley',
            flooding => 'flooding@bexley',
            eh => 'eh@bexley',
        } },
        staff_url => { bexley => {
            'Dead animal' => [ 'message', 'http://public.example.org/dead_animals', 'http://staff.example.org/dead_animals' ],
            'Missing category' => [ 'message', 'http://public.example.org/dead_animals', 'http://staff.example.org/dead_animals' ]
        } },
        category_groups => { bexley => 1 },
    },
}, sub {

    my $cobrand = FixMyStreet::Cobrand::Bexley->new;
    set_fixed_time('2019-10-16T12:00:00Z');
    is $cobrand->_is_out_of_hours(), 0, 'not out of hours in the day';
    set_fixed_time('2019-10-16T04:00:00Z');
    like $cobrand->_is_out_of_hours(), qr/early/, 'out of hours early in the morning';
    set_fixed_time('2019-10-13T12:00:00Z');
    like $cobrand->_is_out_of_hours(), qr/non-work day/, 'out of hours at weekends';
    set_fixed_time('2019-12-25T12:00:00Z');
    like $cobrand->_is_out_of_hours(), qr/public holiday/, 'out of hours on bank holiday';

};

subtest 'out of unusual hours' => sub {

    {
        no warnings 'redefine';
        *FixMyStreet::Cobrand::Bexley::opening_hours = sub {
            {
                open   => { h => 10,  m => 45},
                closed => { h => 14,  m => 30}
            }
        };

        *FixMyStreet::Cobrand::Bexley::non_working_days = sub {
            [4,5]
        };
    }

    # change Bexley's OOH times and retest
    my $bexley = FixMyStreet::Cobrand::Bexley->new;

    ok $bexley->call_hook('opening_hours'), 'Bexley has opening_hours()';
    ok $bexley->call_hook('non_working_days'), 'Bexley has non_working_days()';

    use DDP;
    diag 'OPENING HRS.:';
    diag np $bexley->opening_hours;
    diag 'NON WKG DAYS:';
    diag np $bexley->non_working_days;

    set_fixed_time('2021-12-06T12:00:00Z');
    is $bexley->_is_out_of_hours(), 0, 'still not out of hours at midday';

    set_fixed_time('2021-12-06T10:30:00Z');
    like $bexley->_is_out_of_hours(), qr/early/, 'out of hours "early" at 10:30am';

    set_fixed_time('2021-12-03T12:00:00Z');
    like $bexley->_is_out_of_hours(), qr/non-work day/, 'out of hours on new "non-working" Friday' ;

};

done_testing();
