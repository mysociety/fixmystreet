#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use FixMyStreet;
use FixMyStreet::App;
use FixMyStreet::DB::Result::Contact;
use FixMyStreet::SendReport::Email;
use FixMyStreet::TestMech;
use mySociety::Locale;

my $e = FixMyStreet::SendReport::Email->new();

# area id 1000
my $params = { id => 1000, name => 'Council of the Thousand' };
my $body = FixMyStreet::App->model('DB::Body')->find_or_create($params);
ok $body, "found/created body";

my $contact = FixMyStreet::App->model('DB::Contact')->find_or_create(
    email => 'council@example.com',
    body_id => 1000,
    category => 'category',
    confirmed => 1,
    deleted => 0,
    editor => 'test suite',
    whenedited => DateTime->now,
    note => '',
);

my $row = FixMyStreet::App->model('DB::Problem')->new( {
    bodies_str => '1000',
    category => 'category',
    cobrand => '',
} );

ok $e;

foreach my $test ( {
        desc => 'no councils added means no receipients',
        count => 0,
        add_council => 0,
    },
    {
        desc => 'adding a council results in receipients',
        count => 1,
        add_council => 1,
    },
    {
        desc => 'unconfirmed contact results in no receipients',
        count => 0,
        add_council => 1,
        unconfirmed => 1,
        expected_note => 'Body 1000 deleted',
    },
    {
        desc => 'unconfirmed contact note uses note from contact table',
        count => 0,
        add_council => 1,
        unconfirmed => 1,
        note => 'received bounced so unconfirmed',
        expected_note => 'received bounced so unconfirmed',
    },
) {
    subtest $test->{desc} => sub {
        my $e = FixMyStreet::SendReport::Email->new;
        $contact->update( { confirmed => 0 } ) if $test->{unconfirmed};
        $contact->update( { note => $test->{note} } ) if $test->{note};
        $e->add_body( $body ) if $test->{add_council};
        is $e->build_recipient_list( $row, {} ), $test->{count}, 'correct recipient list count';

        if ( $test->{unconfirmed} ) {
            is_deeply $e->unconfirmed_counts, { 'council@example.com' => { 'category' => 1 } }, 'correct unconfirmed_counts count';
            is_deeply $e->unconfirmed_notes, { 'council@example.com' => { 'category' => $test->{expected_note} } }, 'correct note used';
        }
    };
}

$contact->delete;

done_testing();
