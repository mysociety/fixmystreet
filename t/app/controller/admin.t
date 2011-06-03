use strict;
use warnings;
use Test::More;

use FixMyStreet::TestMech;

my $mech = FixMyStreet::TestMech->new;

$mech->get_ok('/admin');
$mech->title_like(qr/Summary/);

$mech->get_ok('/admin/council_contacts/2650');
$mech->content_contains('Aberdeen City Council');
$mech->content_contains('AB15 8RN');

subtest 'check contact creation' => sub {
    my $contact = FixMyStreet::App->model('DB::Contact')->find(
        { area_id => 2650, category => 'test category' }
    );

    $contact->delete if $contact;

    my $history = FixMyStreet::App->model('DB::ContactsHistory')->search(
        { area_id => 2650, category => 'test category' }
    );

    $history->delete_all;

    $mech->get_ok('/admin/council_contacts/2650');

    $mech->submit_form_ok( { with_fields => { 
        category => 'test category',
        email    => 'test@example.com',
        note     => 'test note',
    } } );

    $mech->content_contains( 'test category' );
    $mech->content_contains( '<td>test@example.com' );
    $mech->content_contains( '<td>test note' );
};

subtest 'check contact editing' => sub {
    $mech->get_ok('/admin/council_edit/2650/test%20category');

    $mech->submit_form_ok( { with_fields => { 
        email    => 'test2@example.com',
        note     => 'test2 note',
    } } );

    $mech->content_contains( 'test category' );
    $mech->content_contains( '<td>test2@example.com' );
    $mech->content_contains( '<td>test2 note' );

    $mech->get_ok('/admin/council_edit/2650/test%20category');
    $mech->content_contains( '<td><strong>test2@example.com' );
};

subtest 'check contact updating' => sub {
    $mech->get_ok('/admin/council_edit/2650/test%20category');
    $mech->content_like(qr{test2\@example.com</strong>[^<]*</td>[^<]*<td>No}s);

    $mech->get_ok('/admin/council_contacts/2650');

    $mech->form_number( 1 );
    $mech->tick( 'confirmed', 'test category' );
    $mech->submit_form_ok({form_number => 1});

    $mech->content_like(qr'test2@example.com</td>[^<]*<td>Yes's);
    $mech->get_ok('/admin/council_edit/2650/test%20category');
    $mech->content_like(qr{test2\@example.com[^<]*</td>[^<]*<td><strong>Yes}s);
};

done_testing();
