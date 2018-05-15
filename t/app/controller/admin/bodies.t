package FixMyStreet::Cobrand::Tester;

use parent 'FixMyStreet::Cobrand::Default';

sub enable_category_groups { 1 }

package main;
use FixMyStreet::TestMech;

my $mech = FixMyStreet::TestMech->new;

my $superuser = $mech->create_user_ok('superuser@example.com', name => 'Super User', is_superuser => 1);
$mech->log_in_ok( $superuser->email );
my $body = $mech->create_body_ok(2650, 'Aberdeen City Council');

# This override is wrapped around ALL the /admin/body tests
FixMyStreet::override_config {
    MAPIT_URL => 'http://mapit.uk/',
    MAPIT_TYPES => [ 'UTA' ],
    BASE_URL => 'http://www.example.org',
}, sub {

$mech->get_ok('/admin/body/' . $body->id);
$mech->content_contains('Aberdeen City Council');
$mech->content_like(qr{AB\d\d});
$mech->content_contains("http://www.example.org/around");

subtest 'check contact creation' => sub {
    $mech->get_ok('/admin/body/' . $body->id);

    $mech->submit_form_ok( { with_fields => { 
        category   => 'test category',
        email      => 'test@example.com',
        note       => 'test note',
        non_public => undef,
        state => 'unconfirmed',
    } } );

    $mech->content_contains( 'test category' );
    $mech->content_contains( 'test@example.com' );
    $mech->content_contains( '<td>test note' );
    $mech->content_like( qr/<td>\s*unconfirmed\s*<\/td>/ ); # No private

    $mech->submit_form_ok( { with_fields => { 
        category   => 'private category',
        email      => 'test@example.com',
        note       => 'test note',
        non_public => 'on',
    } } );

    $mech->content_contains( 'private category' );
    $mech->content_like( qr{test\@example.com\s*</td>\s*<td>\s*confirmed\s*<br>\s*<small>\s*Private\s*</small>\s*</td>} );

    $mech->submit_form_ok( { with_fields => {
        category => 'test/category',
        email    => 'test@example.com',
        note     => 'test/note',
        non_public => 'on',
    } } );
    $mech->get_ok('/admin/body/' . $body->id . '/test/category');
    $mech->content_contains('<h1>test/category</h1>');
};

subtest 'check contact editing' => sub {
    $mech->get_ok('/admin/body/' . $body->id .'/test%20category');
    $mech->content_lacks( 'group</strong> is used for the top-level category' );

    $mech->submit_form_ok( { with_fields => {
        email    => 'test2@example.com',
        note     => 'test2 note',
        non_public => undef,
    } } );

    $mech->content_contains( 'test category' );
    $mech->content_like( qr{test2\@example.com\s*</td>\s*<td>\s*unconfirmed\s*</td>} );
    $mech->content_contains( '<td>test2 note' );

    $mech->get_ok('/admin/body/' . $body->id . '/test%20category');
    $mech->submit_form_ok( { with_fields => {
        email    => 'test2@example.com, test3@example.com',
        note     => 'test3 note',
    } } );

    $mech->content_contains( 'test2@example.com,test3@example.com' );

    $mech->get_ok('/admin/body/' . $body->id . '/test%20category');
    $mech->content_contains( '<td><strong>test2@example.com,test3@example.com' );

    $mech->submit_form_ok( { with_fields => {
        email    => 'test2@example.com',
        note     => 'test2 note',
        non_public => 'on',
    } } );

    $mech->content_like( qr{test2\@example.com\s*</td>\s*<td>\s*unconfirmed\s*<br>\s*<small>\s*Private\s*</small>\s*</td>} );

    $mech->get_ok('/admin/body/' . $body->id . '/test%20category');
    $mech->content_contains( '<td><strong>test2@example.com' );
};

subtest 'check contact updating' => sub {
    $mech->get_ok('/admin/body/' . $body->id . '/test%20category');
    $mech->content_like(qr{test2\@example.com</strong>[^<]*</td>[^<]*<td>unconfirmed}s);

    $mech->get_ok('/admin/body/' . $body->id);

    $mech->form_number( 1 );
    $mech->tick( 'confirmed', 'test category' );
    $mech->submit_form_ok({form_number => 1});

    $mech->content_like(qr'test2@example.com</td>[^<]*<td>\s*confirmed's);
    $mech->get_ok('/admin/body/' . $body->id . '/test%20category');
    $mech->content_like(qr{test2\@example.com[^<]*</td>[^<]*<td><strong>confirmed}s);
};

$body->update({ send_method => undef }); 

subtest 'check open311 configuring' => sub {
    $mech->get_ok('/admin/body/' . $body->id);
    $mech->content_lacks('Council contacts configured via Open311');

    $mech->form_number(3);
    $mech->submit_form_ok(
        {
            with_fields => {
                api_key      => 'api key',
                endpoint     => 'http://example.com/open311',
                jurisdiction => 'mySociety',
                send_comments => 0,
                send_method  => 'Open311',
            }
        }
    );
    $mech->content_contains('Council contacts configured via Open311');
    $mech->content_contains('Values updated');

    my $conf = FixMyStreet::App->model('DB::Body')->find( $body->id );
    is $conf->endpoint, 'http://example.com/open311', 'endpoint configured';
    is $conf->api_key, 'api key', 'api key configured';
    is $conf->jurisdiction, 'mySociety', 'jurisdiction configures';

    $mech->form_number(3);
    $mech->submit_form_ok(
        {
            with_fields => {
                api_key      => 'new api key',
                endpoint     => 'http://example.org/open311',
                jurisdiction => 'open311',
                send_comments => 0,
                send_method  => 'Open311',
            }
        }
    );

    $mech->content_contains('Values updated');

    $conf = FixMyStreet::App->model('DB::Body')->find( $body->id );
    is $conf->endpoint, 'http://example.org/open311', 'endpoint updated';
    is $conf->api_key, 'new api key', 'api key updated';
    is $conf->jurisdiction, 'open311', 'jurisdiction configures';
    ok !$conf->get_extra_metadata('fetch_all_problems'), 'fetch all problems unset';

    $mech->form_number(3);
    $mech->submit_form_ok(
        {
            with_fields => {
                api_key      => 'new api key',
                endpoint     => 'http://example.org/open311',
                jurisdiction => 'open311',
                send_comments => 0,
                send_method  => 'Open311',
                fetch_all_problems => 1,
            }
        }
    );

    $mech->content_contains('Values updated');

    $conf = FixMyStreet::App->model('DB::Body')->find( $body->id );
    ok $conf->get_extra_metadata('fetch_all_problems'), 'fetch all problems set';

    $mech->form_number(3);
    $mech->submit_form_ok(
        {
            with_fields => {
                api_key      => 'new api key',
                endpoint     => 'http://example.org/open311',
                jurisdiction => 'open311',
                send_comments => 0,
                send_method  => 'Open311',
                fetch_all_problems => 0,
            }
        }
    );

    $mech->content_contains('Values updated');

    $conf = FixMyStreet::App->model('DB::Body')->find( $body->id );
    ok !$conf->get_extra_metadata('fetch_all_problems'), 'fetch all problems unset';
};

subtest 'check text output' => sub {
    $mech->get_ok('/admin/body/' . $body->id . '?text=1');
    is $mech->content_type, 'text/plain';
    $mech->content_contains('test category');
    $mech->content_lacks('<body');
};


}; # END of override wrap

FixMyStreet::override_config {
    ALLOWED_COBRANDS => ['tester'],
    MAPIT_URL => 'http://mapit.uk/',
    MAPIT_TYPES => [ 'UTA' ],
    BASE_URL => 'http://www.example.org',
}, sub {
    subtest 'group editing works' => sub {
        $mech->get_ok('/admin/body/' . $body->id);
        $mech->content_contains( 'group</strong> is used for the top-level category' );

        $mech->submit_form_ok( { with_fields => {
            category   => 'grouped category',
            email      => 'test@example.com',
            note       => 'test note',
            group      => 'group a',
            non_public => undef,
            state => 'unconfirmed',
        } } );

        my $contact = $body->contacts->find({ category => 'grouped category' });
        is $contact->get_extra_metadata('group'), 'group a', "group stored correctly";
    };

};


done_testing();
