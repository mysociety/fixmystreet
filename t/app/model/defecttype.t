use strict;
use warnings;
use Test::More;

use FixMyStreet::App;
use FixMyStreet::TestMech;
my $mech = FixMyStreet::TestMech->new;

my $oxfordshire = $mech->create_body_ok(2237, 'Oxfordshire County Council', id => 2237);
my $potholes_contact = $mech->create_contact_ok( body_id => $oxfordshire->id, category => 'Potholes', email => 'potholes@example.com' );
my $traffic_lights_contact =$mech->create_contact_ok( body_id => $oxfordshire->id, category => 'Traffic lights', email => 'lights@example.com' );

my $potholes_defect_type = FixMyStreet::App->model('DB::DefectType')->find_or_create(
    {
        body_id => 2237,
        name => 'Potholes',
        description => 'This defect type is to do with potholes'
    }
);
$potholes_defect_type->contact_defect_types->find_or_create({
    contact_id => $potholes_contact->id,
});

my $general_defect_type = FixMyStreet::App->model('DB::DefectType')->find_or_create(
    {
        body_id => 2237,
        name => 'All categories',
        description => 'This defect type is for all categories'
    }
);


subtest 'for_bodies returns correct results' => sub {
    my $defect_types = FixMyStreet::App->model('DB::DefectType')->for_bodies(
        [ $oxfordshire->id ],
        'Potholes'
    );

    is $defect_types->count, 2, 'Both defect types are included for Potholes category';

    $defect_types = FixMyStreet::App->model('DB::DefectType')->for_bodies(
        [ $oxfordshire->id ],
        'Traffic lights'
    );

    is $defect_types->count, 1, 'Only 1 defect type is included for Traffic lights category';
    is $defect_types->first->name, $general_defect_type->name, 'Correct defect type is returned for Traffic lights category';
};

subtest 'Problem->defect_types behaves correctly' => sub {
    my ($problem) = $mech->create_problems_for_body(1, $oxfordshire->id, 'Test', {
        category => 'Potholes',
    });

    is $problem->defect_types->count, 2, 'Both defect types are available for the problem';

    $problem->update({ category => 'Traffic lights' });
    is $problem->defect_types->count, 1, 'Only 1 defect type is included for Traffic lights category';
    is $problem->defect_types->first->name, $general_defect_type->name, 'Correct defect type is returned for Traffic lights category';
};


END {
    $mech->delete_body( $oxfordshire );

    done_testing();
}
