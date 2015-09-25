use strict;
use warnings;
use Test::More;
use Test::Exception;
use utf8;

use FixMyStreet::DB;
use Data::Dumper;
use DateTime;

my $dt = DateTime->now;
my $user = FixMyStreet::DB->resultset('User')->find_or_create({
        name => 'Bob', email => 'bob@example.com',
});

sub get_report_and_original_data {
    my $report = FixMyStreet::DB->resultset('Problem')->create(
        {
            postcode           => 'BR1 3SB',
            bodies_str         => '',
            areas              => ",,",
            category           => 'Other',
            title              => 'test',
            detail             => 'test',
            used_map           => 't',
            name               => 'Anon',
            anonymous          => 't',
            state              => 'confirmed',
            confirmed          => $dt->ymd . ' ' . $dt->hms,
            lang               => 'en-gb',
            service            => '',
            cobrand            => 'default',
            cobrand_data       => '',
            send_questionnaire => 't',
            latitude           => '51.4129',
            longitude          => '0.007831',
            user => $user,
    });
    my $original = $report->create_related( moderation_original_data => {
        anonymous => 't',
        title => 'test',
        detail => 'test',
        photo => 'f',
        } );

    return ($report, $original);
}

subtest 'Explicit Deletion (sanity test)' => sub {
    my ($report, $orig) = get_report_and_original_data;

    lives_ok {
        $orig->delete;
        $report->delete;
    };
};

subtest 'Implicit Chained Deletion' => sub {
    my ($report, $orig) = get_report_and_original_data;

    lives_ok {
        $report->delete;
    };
};

done_testing();
