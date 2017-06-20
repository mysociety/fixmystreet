use FixMyStreet::App;
use FixMyStreet::TestMech;
use JSON::MaybeXS;

my $mech = FixMyStreet::TestMech->new;
my $area_id = 2237;

my $oxfordshire = $mech->create_body_ok($area_id, 'Oxfordshire County Council');
my $other_body = $mech->create_body_ok($area_id, 'Some Other Council');
my $potholes_contact = $mech->create_contact_ok( body_id => $oxfordshire->id, category => 'Potholes', email => 'potholes@example.com' );
my $traffic_lights_contact =$mech->create_contact_ok( body_id => $oxfordshire->id, category => 'Traffic lights', email => 'lights@example.com' );
my $pavements_contact =$mech->create_contact_ok( body_id => $oxfordshire->id, category => 'Pavements', email => 'pavements@example.com' );

my $potholes_defect_type = FixMyStreet::App->model('DB::DefectType')->find_or_create(
    {
        body_id => $oxfordshire->id,
        name => 'Potholes and Pavements',
        description => 'This defect type is to do with potholes and Pavements'
    }
);
$potholes_defect_type->set_extra_metadata('defect_code' => 123);
$potholes_defect_type->contact_defect_types->find_or_create({
    contact_id => $potholes_contact->id,
});
$potholes_defect_type->contact_defect_types->find_or_create({
    contact_id => $pavements_contact->id,
});
$potholes_defect_type->update();

my $general_defect_type = FixMyStreet::App->model('DB::DefectType')->find_or_create(
    {
        body_id => $oxfordshire->id,
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

subtest 'by_categories returns all defect types grouped by category' => sub {
    my @contacts = FixMyStreet::DB->resultset('Contact')->not_deleted->search( { body_id => [ $oxfordshire->id ] } )->all;
    my $defect_types = FixMyStreet::App->model('DB::DefectType')->by_categories($area_id, @contacts);
    my $potholes = decode_json($defect_types->{Potholes});
    my $traffic_lights = decode_json($defect_types->{'Traffic lights'});
    my $pavements = decode_json($defect_types->{Pavements});

    is scalar @$potholes, 2, 'Potholes have 2 defect types';
    is scalar @$traffic_lights, 1, 'Traffic lights have 1 defect type';
    is scalar @$pavements, 2, 'Pavements have 2 defect types';

    is @$potholes[1]->{extra}->{defect_code}, 123, 'Defect code is present';
};

subtest 'by_categories returns defect types for an area with multiple bodies' => sub {
    FixMyStreet::App->model('DB::DefectType')->find_or_create(
        {
            body_id => $other_body->id,
            name => 'All categories',
            description => 'This defect type is for all categories'
        }
    );

    my @contacts = FixMyStreet::DB->resultset('Contact')->not_deleted->search( { body_id => [ $oxfordshire->id ] } )->all;
    my $defect_types = FixMyStreet::App->model('DB::DefectType')->by_categories($area_id, @contacts);
    my $potholes = decode_json($defect_types->{Potholes});
    my $traffic_lights = decode_json($defect_types->{'Traffic lights'});
    my $pavements = decode_json($defect_types->{Pavements});

    is scalar @$potholes, 3, 'Potholes have 3 defect types';
    is scalar @$traffic_lights, 2, 'Traffic lights have 2 defect type';
    is scalar @$pavements, 3, 'Pavements have 3 defect types';
};

subtest 'by_categories encodes HTML entities' => sub {
    my $apostrophe_defect_type = FixMyStreet::App->model('DB::DefectType')->find_or_create(
        {
            body_id => $oxfordshire->id,
            name => 'This defect type\'s name has an apostrophe',
            description => 'This defect type is for all categories'
        }
    );
    $apostrophe_defect_type->set_extra_metadata('defect_code' => 'Here\'s an apostrophe');
    $apostrophe_defect_type->update();

    my @contacts = FixMyStreet::DB->resultset('Contact')->not_deleted->search( { body_id => [ $oxfordshire->id ] } )->all;
    my $defect_types = FixMyStreet::App->model('DB::DefectType')->by_categories($area_id, @contacts);
    my $traffic_lights = decode_json($defect_types->{'Traffic lights'});
    my $defect_type = @$traffic_lights[2];
    is $defect_type->{name}, 'This defect type&#39;s name has an apostrophe';
    is $defect_type->{extra}->{defect_code}, 'Here&#39;s an apostrophe';

};


END {
    done_testing();
}
