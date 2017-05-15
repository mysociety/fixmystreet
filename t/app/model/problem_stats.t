use strict;
use warnings;
use Test::More;

use FixMyStreet::App;
use FixMyStreet::TestMech;
use JSON::MaybeXS;

my $mech = FixMyStreet::TestMech->new;
my $oxfordshire = $mech->create_body_ok(2237, 'Oxfordshire County Council', { id => 2237 });

my $area_id = '123';

my ($problem1) = $mech->create_problems_for_body(1, $oxfordshire->id, 'Title', { areas => ",$area_id,6753,4324,", whensent => \'current_timestamp' });
my ($problem2) = $mech->create_problems_for_body(1, $oxfordshire->id, 'Title', { areas => ",6753,$area_id,4324,", whensent => \'current_timestamp' });
my ($problem3) = $mech->create_problems_for_body(1, $oxfordshire->id, 'Title', { areas => ",$area_id,6753,4324,", whensent => \"current_timestamp-'60 days'::interval" });
my ($problem4) = $mech->create_problems_for_body(1, $oxfordshire->id, 'Title', { areas => ",6753,4324,", whensent => \'current_timestamp' });

subtest 'in_area returns correct number of problems in a given area' => sub {
    my $in_area = FixMyStreet::DB->resultset('Problem')->in_area($area_id);

    is $in_area->count, 3, 'correct count is returned';

    $in_area = FixMyStreet::DB->resultset('Problem')->in_area($area_id)->search({
      whensent  => { '>=', \"current_timestamp-'30 days'::interval" }
    });

    is $in_area->count, 2, 'allows filtering by date';
};

END {
    $mech->delete_body($oxfordshire);
    done_testing();
}
