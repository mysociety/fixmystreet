use FixMyStreet::TestMech;
use JSON::MaybeXS;

my $mech = FixMyStreet::TestMech->new;
my $area_id = 2651;

my $body = $mech->create_body_ok($area_id, 'Edinburgh Council');
my $c1 = $mech->create_contact_ok(category => 'Potholes', body_id => $body->id, email => 'p');
my $c2 = $mech->create_contact_ok(category => 'Graffiti', body_id => $body->id, email => 'g');
my $t1 = FixMyStreet::DB->resultset('ResponseTemplate')->create({ body_id => $body->id, title => "Title 1", text => "Text 1" });
my $t2 = FixMyStreet::DB->resultset('ResponseTemplate')->create({ body_id => $body->id, title => "Title 2", text => "Text 2", state => 'investigating' });
my $t3 = FixMyStreet::DB->resultset('ResponseTemplate')->create({ body_id => $body->id, title => "Title 3", text => "Text 3" });
$t1->add_to_contacts($c1);
$t2->add_to_contacts($c2);

my @contacts = FixMyStreet::DB->resultset('Contact')->not_deleted->search( { body_id => [ $body->id ] } )->all;

subtest 'by_categories returns allresponse templates grouped by category' => sub {
    my $templates = FixMyStreet::DB->resultset('ResponseTemplate')->by_categories(\@contacts, body_id => $body->id);
    my $potholes = decode_json($templates->{Potholes});
    my $graffiti = decode_json($templates->{Graffiti});

    is scalar @$potholes, 2, 'Potholes have 2 templates';
    is scalar @$graffiti, 2, 'Graffiti has 2 templates';
    is $graffiti->[0]->{state}, 'investigating', 'Graffiti first template has right state';
};

done_testing;
