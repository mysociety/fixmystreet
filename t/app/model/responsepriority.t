use FixMyStreet::TestMech;
use JSON::MaybeXS;

my $mech = FixMyStreet::TestMech->new;
my $area_id = 2237;

my $oxfordshire = $mech->create_body_ok($area_id, 'Oxfordshire County Council');
my $other_body = $mech->create_body_ok($area_id, 'Some Other Council');
my $potholes_contact = $mech->create_contact_ok( body_id => $oxfordshire->id, category => 'Potholes', email => 'potholes@example.com' );
my $traffic_lights_contact =$mech->create_contact_ok( body_id => $oxfordshire->id, category => 'Traffic lights', email => 'lights@example.com' );
my @contacts = FixMyStreet::DB->resultset('Contact')->not_deleted->search( { body_id => [ $oxfordshire->id ] } )->all;

my $potholes_response_priority = FixMyStreet::DB->resultset('ResponsePriority')->find_or_create(
    {
        body_id => $oxfordshire->id,
        name => 'Potholes',
        description => 'This priority is to do with potholes'
    }
);
$potholes_response_priority->contact_response_priorities->find_or_create({
    contact_id => $potholes_contact->id,
});

my $general_response_priority = FixMyStreet::DB->resultset('ResponsePriority')->find_or_create(
    {
        body_id => $oxfordshire->id,
        name => 'All categories',
        description => 'This priority is for all categories'
    }
);

my $deleted1_response_priority = FixMyStreet::DB->resultset('ResponsePriority')->find_or_create(
    {
        body_id => $oxfordshire->id,
        name => 'Deleted priority 1',
        description => 'This priority has been deleted',
        deleted => 1,
    }
);

my $deleted2_response_priority = FixMyStreet::DB->resultset('ResponsePriority')->find_or_create(
    {
        body_id => $oxfordshire->id,
        name => 'Deleted priority 2',
        description => 'This priority has been deleted',
        deleted => 1,
    }
);

subtest 'for_bodies returns correct results (including deleted)' => sub {
    my $priorities = FixMyStreet::DB->resultset('ResponsePriority')->for_bodies(
        [ $oxfordshire->id ],
        'Potholes'
    );

    is $priorities->count, 4, 'all priorities are included for Potholes category';

    $priorities = FixMyStreet::DB->resultset('ResponsePriority')->for_bodies(
        [ $oxfordshire->id ],
        'Traffic lights'
    );

    is $priorities->count, 3, 'Pothole-only priority ignored for Traffic lights category';
    is $priorities->first->name, $general_response_priority->name, 'Correct priority is returned for Traffic lights category';
};

subtest 'by_categories returns all undeleted response priorities grouped by category' => sub {
    my $priorities = FixMyStreet::DB->resultset('ResponsePriority')->by_categories(\@contacts, body_id => $oxfordshire->id);
    my $potholes = decode_json($priorities->{Potholes});
    my $traffic_lights = decode_json($priorities->{'Traffic lights'});

    is scalar @$potholes, 2, 'Potholes have 2 defect types';
    is scalar @$traffic_lights, 1, 'Traffic lights have 1 defect type';
};

subtest 'by_categories returns all undeleted response priorities for an area with multiple bodies' => sub {
    my $other_response_priority = FixMyStreet::DB->resultset('ResponsePriority')->find_or_create(
        {
            body_id => $other_body->id,
            name => 'All categories',
            description => 'This priority is for all categories'
        }
    );

    my $priorities = FixMyStreet::DB->resultset('ResponsePriority')->by_categories(\@contacts, area_id => $area_id);
    my $potholes = decode_json($priorities->{Potholes});
    my $traffic_lights = decode_json($priorities->{'Traffic lights'});

    is scalar @$potholes, 3, 'Potholes have 3 defect types';
    is scalar @$traffic_lights, 2, 'Traffic lights have 2 defect types';
};

subtest 'test with existing problem' => sub {
    my ($problem) = $mech->create_problems_for_body(1, $oxfordshire->id, 'Title', {
        response_priority => $deleted1_response_priority,
    });
    my $priorities = FixMyStreet::DB->resultset('ResponsePriority')->by_categories(\@contacts,
        area_id => $area_id, problem => $problem);
    my $potholes = decode_json($priorities->{Potholes});
    my $traffic_lights = decode_json($priorities->{'Traffic lights'});
    is scalar @$potholes, 4, 'Potholes have 4 defect types, deleted is included';
    is scalar @$traffic_lights, 3, 'Traffic lights have 3 defect types, deleted is included';
};

done_testing();
