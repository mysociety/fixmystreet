use strict;
use warnings;
use Test::More;
use utf8;

use FixMyStreet::App;
use Data::Dumper;
use DateTime;

my $c = FixMyStreet::App->new;

my $db = FixMyStreet::App->model('DB')->schema;
$db->txn_begin;

my $body = $db->resultset('Body')->create({ name => 'ExtraTestingBody' });

my $serial = 1;
sub get_test_contact {
    my $contact = $db->resultset('Contact')->create({
        category => "Testing ${serial}",
        body => $body,
        email => 'test@example.com',
        confirmed => 1,
        deleted => 0,
        editor => 'test script',
        note => 'test script',
        whenedited => DateTime->now(),
    });
    $serial++;
    return $contact;
}

subtest 'Standard (list) layout' => sub {
    $c->stash->{cobrand} = FixMyStreet::Cobrand->get_class_for_moniker('default')->new({ c => $c });

    subtest 'layout' => sub {
        my $contact = get_test_contact();

        is_deeply $contact->get_extra($c), [], 'default layout is array';
    };

    subtest 'extra fields' => sub {
        my $contact = get_test_contact();

        is_deeply $contact->get_extra_fields($c), [], 'No extra fields';

        my @fields = ( { a => 1 }, { b => 2 } );
        $contact->set_extra_fields($c, @fields);
        is_deeply $contact->extra, \@fields, 'extra fields set...';
        $contact->update;
        $contact->discard_changes;
        is_deeply $contact->extra, \@fields, '...and retrieved';
        is_deeply $contact->get_extra_fields($c), \@fields, 'extra fields returned';
    };

    subtest 'metadata' => sub {
        my $contact = get_test_contact();
        is_deeply $contact->get_extra_metadata_as_hashref($c), {}, 'No extra metadata';

        $contact->set_extra_metadata($c, 'foo' => 'bar');
        is $contact->get_extra_metadata($c, 'foo'), undef, 'extra metadata not set...';
        $contact->update;
        $contact->discard_changes;
        is $contact->get_extra_metadata($c, 'foo'), undef, '... nor retrieved';
        is_deeply $contact->get_extra_metadata_as_hashref($c), {}, 'No extra metadata';
    };
};

subtest 'Alternate (hash) layout' => sub {
  FixMyStreet::override_config { ALLOWED_COBRANDS => [ 'zurich' ] } => sub {
    $c->stash->{cobrand} = FixMyStreet::Cobrand->get_class_for_moniker('zurich')->new({ c => $c });

    subtest 'layout' => sub {
        my $contact = get_test_contact();

        is_deeply $contact->get_extra($c), {}, 'default layout is hash';
    };

    subtest 'extra fields' => sub {
        my $contact = get_test_contact();

        is_deeply $contact->get_extra_fields($c), [], 'No extra fields';

        my @fields = ( { a => 1 }, { b => 2 } );
        $contact->set_extra_fields($c, @fields);
        is_deeply $contact->get_extra_fields, \@fields, 'extra fields set...';
        $contact->update;
        $contact->discard_changes;
        is_deeply $contact->get_extra_fields($c), \@fields, '... and returned';
        is_deeply $contact->extra, { _fields => \@fields }, '(sanity check layout)';
    };

    subtest 'metadata' => sub {
        my $contact = get_test_contact();
        is_deeply $contact->get_extra_metadata_as_hashref($c), {}, 'No extra metadata';

        $contact->set_extra_metadata($c, 'foo' => 'bar');
        is $contact->get_extra_metadata($c, 'foo'), 'bar', 'extra metadata set...';
        $contact->update;
        $contact->discard_changes;
        is $contact->get_extra_metadata($c, 'foo'), 'bar', '... and retrieved';
        is_deeply $contact->get_extra_metadata_as_hashref($c), { foo => 'bar' }, 'No extra metadata';

        $contact->unset_extra_metadata($c, 'foo');
        is $contact->get_extra_metadata($c, 'foo'), undef, 'extra metadata now unset';
        $contact->update;
        $contact->discard_changes;
        is $contact->get_extra_metadata($c, 'foo'), undef, '... after retrieval';
    };
  };
};

$db->txn_rollback;
done_testing();
