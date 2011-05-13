use strict;
use warnings;
use Test::More;

use FixMyStreet::TestMech;

my $mech = FixMyStreet::TestMech->new;

$mech->get_ok('/contact');
$mech->title_like(qr/Contact Us/);
$mech->content_contains("We'd love to hear what you think about this site");

subtest 'check reporting a problem displays correctly' => sub {
    my $user = FixMyStreet::App->model('DB::User')->find_or_create(
        {
            name  => 'A User',
            email => 'problem_report_rest@example.com'
        }
    );

    my $problem = FixMyStreet::App->model('DB::Problem')->create(
        {
            title     => 'Some problem or other',
            detail    => 'More detail on the problem',
            postcode  => 'EH99 1SP',
            confirmed => '2011-05-04 10:44:28.145168',
            latitude  => 0,
            longitude => 0,
            areas     => 0,
            used_map  => 0,
            name      => 'Problem User',
            anonymous => 0,
            state     => 'confirmed',
            user      => $user
        }
    );

    ok $problem, 'succesfully create a problem';

    $mech->get_ok( '/contact?id=' . $problem->id );
    $mech->content_contains('reporting the following problem');
    $mech->content_contains('Some problem or other');
    $mech->content_contains('Reported by A User');
    $mech->content_contains(
        'Reported by A User at 10:44, Wednesday  4 May 2011');

    $problem->delete;
};

done_testing();
