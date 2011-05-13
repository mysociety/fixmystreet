use strict;
use warnings;
use Test::More;

use FixMyStreet::TestMech;

my $mech = FixMyStreet::TestMech->new;

$mech->get_ok('/contact');
$mech->title_like(qr/Contact Us/);
$mech->content_contains("We'd love to hear what you think about this site");

for my $test (
    {
        name      => 'A User',
        email     => 'problem_report_test@example.com',
        title     => 'Some problem or other',
        detail    => 'More detail on the problem',
        postcode  => 'EH99 1SP',
        confirmed => '2011-05-04 10:44:28.145168',
        anonymous => 0,
        meta      => 'Reported by A User at 10:44, Wednesday  4 May 2011',
    },
    {
        name      => 'A User',
        email     => 'problem_report_test@example.com',
        title     => 'A different problem',
        detail    => 'More detail on the different problem',
        postcode  => 'EH99 1SP',
        confirmed => '2011-05-03 13:24:28.145168',
        anonymous => 1,
        meta      => 'Reported anonymously at 13:24, Tuesday  3 May 2011',
    },
  )
{
    subtest 'check reporting a problem displays correctly' => sub {
        my $user = FixMyStreet::App->model('DB::User')->find_or_create(
            {
                name  => $test->{name},
                email => $test->{email}
            }
        );

        my $problem = FixMyStreet::App->model('DB::Problem')->create(
            {
                title     => $test->{title},
                detail    => $test->{detail},
                postcode  => $test->{postcode},
                confirmed => $test->{confirmed},
                name      => $test->{name},
                anonymous => $test->{anonymous},
                state     => 'confirmed',
                user      => $user,
                latitude  => 0,
                longitude => 0,
                areas     => 0,
                used_map  => 0,
            }
        );

        ok $problem, 'succesfully create a problem';

        $mech->get_ok( '/contact?id=' . $problem->id );
        $mech->content_contains('reporting the following problem');
        $mech->content_contains( $test->{title} );
        $mech->content_contains( $test->{meta} );

        $problem->delete;
    };
}

done_testing();
