use FixMyStreet::Test;

use DateTime;

my $db = FixMyStreet::DB->schema;

my $body = $db->resultset('Body')->create({ name => 'ExtraTestingBody' });

my $serial = 1;
sub get_test_contact {
    my $extra = shift;
    my $contact = $db->resultset('Contact')->create({
        category => "Testing ${serial}",
        body => $body,
        email => 'test@example.com',
        state => 'confirmed',
        editor => 'test script',
        note => 'test script',
        whenedited => DateTime->now(),
        $extra ? ( extra => $extra ) : (),
    });
    $serial++;
    return $contact;
}

subtest 'Old list layout transparently upgraded' => sub {

    subtest 'layout' => sub {
        my $contact = get_test_contact([]);

        is_deeply $contact->get_extra(), { _fields => [] }, 'transparently upgraded to a hash';
    };

    subtest 'extra fields' => sub {
        my $contact = get_test_contact([]);

        is_deeply $contact->get_extra_fields(), [], 'No extra fields';

        my @fields = ( { a => 1 }, { b => 2 } );
        $contact->set_extra_fields(@fields);
        is_deeply $contact->extra, { _fields => \@fields }, 'extra fields set...';
        $contact->update;
        $contact->discard_changes;
        is_deeply $contact->extra, { _fields => \@fields }, '...and retrieved';
        is_deeply $contact->get_extra_fields(), \@fields, 'extra fields returned';
    };

    subtest 'metadata' => sub {
        my $contact = get_test_contact([]);
        is_deeply $contact->get_extra_metadata, {}, 'No extra metadata';

        $contact->set_extra_metadata('foo' => 'bar');
        is $contact->get_extra_metadata('foo'), 'bar', 'extra metadata set...';
        $contact->update;
        $contact->discard_changes;
        is $contact->get_extra_metadata('foo'), 'bar', '... and retrieved';
        is_deeply $contact->get_extra_metadata, { foo => 'bar' }, 'No extra metadata';
    };
};

subtest 'Default hash layout' => sub {
    subtest 'layout' => sub {
        my $contact = get_test_contact();

        is_deeply $contact->get_extra(), {}, 'default layout is hash';
    };

    subtest 'extra fields' => sub {
        my $contact = get_test_contact();

        is_deeply $contact->get_extra_fields(), [], 'No extra fields';

        my @fields = ( { a => 1 }, { b => 2 } );
        $contact->set_extra_fields(@fields);
        is_deeply $contact->get_extra_fields, \@fields, 'extra fields set...';
        $contact->update;
        $contact->discard_changes;
        is_deeply $contact->get_extra_fields(), \@fields, '... and returned';
        is_deeply $contact->extra, { _fields => \@fields }, '(sanity check layout)';
    };

    subtest 'metadata' => sub {
        my $contact = get_test_contact();
        is_deeply $contact->get_extra_metadata, {}, 'No extra metadata';

        $contact->set_extra_metadata('foo' => 'bar');
        is $contact->get_extra_metadata('foo'), 'bar', 'extra metadata set...';
        $contact->update;
        $contact->discard_changes;
        is $contact->get_extra_metadata( 'foo'), 'bar', '... and retrieved';
        is_deeply $contact->get_extra_metadata, { foo => 'bar' }, 'No extra metadata';

        $contact->unset_extra_metadata('foo');
        is $contact->get_extra_metadata('foo'), undef, 'extra metadata now unset';
        $contact->update;
        $contact->discard_changes;
        is $contact->get_extra_metadata('foo'), undef, '... after retrieval';
    };
};

subtest 'Get named field values' => sub {
    my $user = $db->resultset('User')->create({
        email => 'test-moderation@example.com',
        email_verified => 1,
        name => 'Test User'
    });
    my $report = $db->resultset('Problem')->create(
    {
        postcode           => 'BR1 3SB',
        bodies_str         => "",
        areas              => "",
        category           => 'Other',
        title              => 'Good bad good',
        detail             => 'Good bad bad bad good bad',
        used_map           => 't',
        name               => 'Test User 2',
        anonymous          => 'f',
        state              => 'confirmed',
        lang               => 'en-gb',
        service            => '',
        cobrand            => 'default',
        latitude           => '51.4129',
        longitude          => '0.007831',
        user_id            => $user->id,
    });

    $report->push_extra_fields(
        {
            name => "field1",
            description => "This is a test field",
            value => "value 1",
        },
        {
            name => "field 2",
            description => "Another test",
            value => "this is a test value",
        }
    );

    is $report->get_extra_field_value("field1"), "value 1", "field1 has correct value";
    is $report->get_extra_field_value("field 2"), "this is a test value", "field 2 has correct value";
};

done_testing();
