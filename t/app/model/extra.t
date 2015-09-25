use strict;
use warnings;
use Test::More;
use utf8;

use FixMyStreet::DB;
use Data::Dumper;
use DateTime;

my $db = FixMyStreet::DB->connect;
$db->txn_begin;

my $body = $db->resultset('Body')->create({ name => 'ExtraTestingBody' });

my $serial = 1;
sub get_test_contact {
    my $extra = shift;
    my $contact = $db->resultset('Contact')->create({
        category => "Testing ${serial}",
        body => $body,
        email => 'test@example.com',
        confirmed => 1,
        deleted => 0,
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
        is_deeply $contact->get_extra_metadata_as_hashref(), {}, 'No extra metadata';

        $contact->set_extra_metadata('foo' => 'bar');
        is $contact->get_extra_metadata('foo'), 'bar', 'extra metadata set...';
        $contact->update;
        $contact->discard_changes;
        is $contact->get_extra_metadata('foo'), 'bar', '... and retrieved';
        is_deeply $contact->get_extra_metadata_as_hashref(), { foo => 'bar' }, 'No extra metadata';
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
        is_deeply $contact->get_extra_metadata_as_hashref(), {}, 'No extra metadata';

        $contact->set_extra_metadata('foo' => 'bar');
        is $contact->get_extra_metadata('foo'), 'bar', 'extra metadata set...';
        $contact->update;
        $contact->discard_changes;
        is $contact->get_extra_metadata( 'foo'), 'bar', '... and retrieved';
        is_deeply $contact->get_extra_metadata_as_hashref(), { foo => 'bar' }, 'No extra metadata';

        $contact->unset_extra_metadata('foo');
        is $contact->get_extra_metadata('foo'), undef, 'extra metadata now unset';
        $contact->update;
        $contact->discard_changes;
        is $contact->get_extra_metadata('foo'), undef, '... after retrieval';
    };
};

$db->txn_rollback;
done_testing();
