use FixMyStreet::TestMech;
use JSON::MaybeXS;

my $mech = FixMyStreet::TestMech->new;
my $area_id = 2651;

my $body = $mech->create_body_ok($area_id, 'Edinburgh Council');
my $c1 = $mech->create_contact_ok(category => 'Potholes', body_id => $body->id, email => 'p');
my $c2 = $mech->create_contact_ok(category => 'Graffiti', body_id => $body->id, email => 'g');
my $t1 = FixMyStreet::DB->resultset('ResponseTemplate')->create({ body_id => $body->id, title => "Title 1", text => "Text 1 ⛄" });
my $t2 = FixMyStreet::DB->resultset('ResponseTemplate')->create({ body_id => $body->id, title => "Title 2", text => "Text 2", state => 'investigating' });
my $t3 = FixMyStreet::DB->resultset('ResponseTemplate')->create({ body_id => $body->id, title => "Title 3", text => "Text 3" });
$t1->add_to_contacts($c1);
$t2->add_to_contacts($c2);

my @contacts = FixMyStreet::DB->resultset('Contact')->not_deleted->search( { body_id => [ $body->id ] } )->all;

subtest 'by_categories returns all response templates grouped by category' => sub {
    my $templates = FixMyStreet::DB->resultset('ResponseTemplate')->by_categories(\@contacts, body_id => $body->id);
    my $potholes = JSON::MaybeXS->new->decode($templates->{Potholes});
    my $graffiti = JSON::MaybeXS->new->decode($templates->{Graffiti});

    is scalar @$potholes, 2, 'Potholes have 2 templates';
    is scalar @$graffiti, 2, 'Graffiti has 2 templates';
    is $graffiti->[0]->{state}, 'investigating', 'Graffiti first template has right state';
    is $potholes->[0]->{id}, 'Text 1 ⛄', 'Pothole first template has right text';
    is $graffiti->[1]->{id}, $potholes->[1]->{id},
        '3rd template applies to both graffiti and potholes';
    # is $graffiti->[1]->external_status_code, '060',
    #     'Whitespace trimmed from external_status_code';
};

subtest 'Trim whitespace on external_status_code' => sub {
    my $t_whitespace
        = FixMyStreet::DB->resultset('ResponseTemplate')->create(
        {   body_id              => $body->id,
            title                => 'Title',
            text                 => 'Text',
            external_status_code => " 　    \t\n060\n\t 　   ",
        }
        );

    note 'Create template:';
    is $t_whitespace->external_status_code, '060',
        'external_status_code correctly munged';

    note 'Update with external_status_code arg:';
    $t_whitespace->update( { external_status_code => ' 171 ' } );
    $t_whitespace->discard_changes;
    is $t_whitespace->external_status_code, '171',
        'external_status_code correctly munged';

    note 'Unset with external_status_code arg:';
    $t_whitespace->update( { external_status_code => undef } );
    $t_whitespace->discard_changes;
    is $t_whitespace->external_status_code, undef,
        'external_status_code unset';

    note 'Set external_status_code followed by call to update:';
    $t_whitespace->external_status_code(' 282 ');
    $t_whitespace->update;
    $t_whitespace->discard_changes;
    is $t_whitespace->external_status_code, '282',
        'external_status_code correctly munged';

    note 'Unset external_status_code followed by call to update:';
    $t_whitespace->external_status_code(undef);
    $t_whitespace->update;
    $t_whitespace->discard_changes;
    is $t_whitespace->external_status_code, undef,
        'external_status_code unset';

    note 'Set external_status_code AND pass arg to update:';
    $t_whitespace->external_status_code(' 393 ');
    $t_whitespace->update( { external_status_code => ' 404 ' } );
    $t_whitespace->discard_changes;
    is $t_whitespace->external_status_code, '404',
        'arg passed to update takes precedence';
};

done_testing;
