use FixMyStreet;
BEGIN { FixMyStreet->test_mode(1); }

package FixMyStreet::Cobrand::AnonAllowedByCategory;
use parent 'FixMyStreet::Cobrand::UKCouncils';
sub council_url { 'anonbycategory' }
sub council_name { 'Aberdeen City Council' }
sub council_area { 'Aberdeen' }
sub council_area_id { 2650 }
sub anonymous_account { { email => 'anoncategory@example.org', name => 'Anonymous Category' } }

package main;

use FixMyStreet::TestMech;

my $mech = FixMyStreet::TestMech->new;

my $superuser = $mech->create_user_ok('superuser@example.com', name => 'Super User', is_superuser => 1);
$mech->log_in_ok( $superuser->email );
my $body = $mech->create_body_ok(2650, 'Aberdeen City Council');
my $body2 = $mech->create_body_ok(2237, 'Oxfordshire County Council', { cobrand => 'oxfordshire' });
my $bucks = $mech->create_body_ok(2217, 'Buckinghamshire Council', { cobrand => 'buckinghamshire' });

my $user = $mech->create_user_ok('user@example.com', name => 'OCC User', from_body => $body2);
$user->user_body_permissions->create({ body => $body2, permission_type => 'category_edit' });

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

subtest 'check body creation' => sub {
    $mech->get_ok('/admin/bodies');
    $mech->follow_link_ok({ text => 'Add body' });

    $mech->submit_form_ok( { with_fields => {
        name => 'New body',
    } } );
    $mech->content_contains('New body');
    $mech->get_ok('/admin/bodies');
    $mech->content_contains('New body');
};

subtest 'check contact creation' => sub {
    $mech->get_ok('/admin/body/' . $body->id);
    $mech->follow_link_ok({ text => 'Add new category' });

    $mech->submit_form_ok( { with_fields => {
        category   => 'test category',
        title_hint => 'example in test category',
        email      => 'test@example.com',
        note       => 'test note',
        non_public => undef,
        state => 'unconfirmed',
    } } );

    $mech->content_contains( 'test category' );
    $mech->content_contains( 'test@example.com' );
    $mech->content_contains( '<td>test note' );
    $mech->content_like( qr/<td>\s*unconfirmed\s*<\/td>/ ); # No private

    $mech->follow_link_ok({ text => 'Add new category' });
    $mech->submit_form_ok( { with_fields => {
        category   => 'private category',
        email      => 'test@example.com',
        note       => 'test note',
        non_public => 'on',
    } } );

    $mech->content_contains( 'private category' );
    $mech->content_like( qr{test\@example.com\s*</td>\s*<td>\s*confirmed\s*<br>\s*<small>\s*Private\s*</small>\s*</td>} );

    $mech->follow_link_ok({ text => 'Add new category' });
    $mech->submit_form_ok( { with_fields => {
        category => 'test/category',
        email    => 'test@example.com',
        note     => 'test/note',
        non_public => 'on',
    } } );

    $mech->follow_link_ok({ text => 'Add new category' });
    $mech->submit_form_ok( { with_fields => {
        category => 'test \' ’ category',
        email    => 'test@example.com',
        note     => 'note',
    } } );
    $mech->content_contains("/test%20'%20%E2%80%99%20category");

    $mech->get_ok('/admin/body/' . $body->id . '/test/category');
    $mech->content_contains('test/category');
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

    $mech->content_contains( 'test2@example.com, test3@example.com' );

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

subtest 'check contact renaming' => sub {
    my ($report) = $mech->create_problems_for_body(1, $body->id, 'Title', { category => 'test category' });
    $mech->get_ok('/admin/body/' . $body->id .'/test%20category');
    $mech->submit_form_ok( { with_fields => { category => 'private category' } } );
    $mech->content_contains('You cannot rename');
    $mech->submit_form_ok( { with_fields => { category => 'testing category' } } );
    $mech->content_contains( 'testing category' );
    $mech->get('/admin/body/' . $body->id . '/test%20category');
    is $mech->res->code, 404;
    $mech->get_ok('/admin/body/' . $body->id . '/testing%20category');
    $mech->content_contains('<td><strong>test2@example.com</strong></td>');
    $report->discard_changes;
    is $report->category, 'testing category';
    $mech->submit_form_ok( { with_fields => { category => 'test category' } } );
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

    my $conf = FixMyStreet::DB->resultset('Body')->find( $body->id );
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

    $conf = FixMyStreet::DB->resultset('Body')->find( $body->id );
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
                'extra[fetch_all_problems]' => 1,
            }
        }
    );

    $mech->content_contains('Values updated');

    $conf = FixMyStreet::DB->resultset('Body')->find( $body->id );
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
                'extra[fetch_all_problems]' => 0,
                can_be_devolved => 1, # for next test
            }
        }
    );

    $mech->content_contains('Values updated');

    $conf = FixMyStreet::DB->resultset('Body')->find( $body->id );
    ok !$conf->get_extra_metadata('fetch_all_problems'), 'fetch all problems unset';
};

subtest 'check open311 devolved editing' => sub {
    $mech->get_ok('/admin/body/' . $body->id . '/test%20category');
    $mech->content_contains("name=\"category\"\n    size=\"30\" value=\"test category\"\n    readonly>", 'Cannot edit Open311 category name');
    $mech->submit_form_ok( { with_fields => {
        send_method => 'Email',
        email => 'testing@example.org',
        note => 'Updating contact to email',
    } } );
    $mech->content_contains('Values updated');
    $mech->get_ok('/admin/body/' . $body->id . '/test%20category');
    $mech->content_contains("name=\"category\"\n    size=\"30\" value=\"test category\"\n    required>", 'Can edit as now devolved');
    $mech->submit_form_ok( { with_fields => {
        send_method => '',
        email => 'open311 code',
        note => 'Removing email send method',
    } } );
    $mech->content_contains('open311 code');
    $mech->content_contains('Values updated');
};

subtest 'check text output' => sub {
    $mech->get_ok('/admin/body/' . $body->id . '?text=1');
    is $mech->content_type, 'text/plain';
    $mech->content_contains('test category');
    $mech->content_lacks('<body');
};

subtest 'disable form message editing' => sub {
    $mech->get_ok('/admin/body/' . $body->id . '/test%20category');
    $mech->submit_form_ok( { with_fields => {
        disable => 1,
        disable_message => '<em>Please</em> <u>ring</u> us on <a href="tel:01234">01234</a>, click <a href="javascript:bad">bad</a>',
        note => 'Adding emergency message',
    } } );
    $mech->content_contains('Values updated');
    my $contact = $body->contacts->find({ category => 'test category' });
    is_deeply $contact->get_extra_fields, [{
        description => '<em>Please</em> ring us on <a href="tel:01234">01234</a>, click <a>bad</a>',
        code => '_fms_disable_',
        protected => 'true',
        variable => 'false',
        disable_form => 'true',
    }], 'right message added';
};

subtest 'open311 protection editing' => sub {
    $mech->get_ok('/admin/body/' . $body->id . '/test%20category');
    $mech->submit_form_ok( { with_fields => {
        open311_protect => 1,
        note => 'Protected from Open311 changes',
    } } );
    $mech->content_contains('Values updated');
    my $contact = $body->contacts->find({ category => 'test category' });
    is $contact->get_extra_metadata('open311_protect'), 1, 'Open311 protect flag set';
};

subtest 'test assigned_users_only setting' => sub {
    $mech->get_ok('/admin/body/' . $body->id . '/test%20category');
    $mech->submit_form_ok( { with_fields => {
        assigned_users_only => 1,
    } } );
    $mech->content_contains('Values updated');
    my $contact = $body->contacts->find({ category => 'test category' });
    is $contact->get_extra_metadata('assigned_users_only'), 1;
};

subtest 'test prefer_if_multiple setting' => sub {
    $mech->get_ok('/admin/body/' . $body->id . '/test%20category');
    $mech->submit_form_ok( { with_fields => {
        prefer_if_multiple => 1,
    } } );
    $mech->content_contains('Values updated');
    my $contact = $body->contacts->find({ category => 'test category' });
    is $contact->get_extra_metadata('prefer_if_multiple'), 1;
};

subtest 'updates disabling' => sub {
    $mech->get_ok('/admin/body/' . $body->id . '/test%20category');
    $mech->submit_form_ok( { with_fields => {
        updates_disallowed => 1,
        note => 'Disabling updates',
    } } );
    $mech->content_contains('Values updated');
    my $contact = $body->contacts->find({ category => 'test category' });
    is $contact->get_extra_metadata('updates_disallowed'), 1, 'Updates disallowed flag set';
};

subtest 'reopen disabling' => sub {
    $mech->get_ok('/admin/body/' . $body->id . '/test%20category');
    $mech->submit_form_ok( { with_fields => {
        reopening_disallowed => 1,
        note => 'Disabling reopening',
    } } );
    $mech->content_contains('Values updated');
    my $contact = $body->contacts->find({ category => 'test category' });
    is $contact->get_extra_metadata('reopening_disallowed'), 1, 'Reopening disallowed flag set';
};

subtest 'set HE litter category' => sub {
    $mech->get_ok('/admin/body/' . $body->id . '/test%20category');
    $mech->submit_form_ok( { with_fields => {
        litter_category_for_he => 1,
        note => 'Setting litter category for Highways England filtering',
    } } );
    $mech->content_contains('Values updated');
    my $contact = $body->contacts->find({ category => 'test category' });
    is $contact->get_extra_metadata('litter_category_for_he'), 1, 'Litter category set for Highways England filtering';
};

subtest 'closure timespan setting' => sub {
    $mech->get_ok('/admin/body/' . $body->id . '/test%20category');

    # Test setting valid closure timespan with 'm' suffix
    $mech->submit_form_ok( { with_fields => {
        closure_timespan => '3m',
        note => 'Setting closure timespan to 3 months',
    } } );
    $mech->content_contains('Values updated');
    my $contact = $body->contacts->find({ category => 'test category' });
    is $contact->get_extra_metadata('closure_timespan'), '3m', 'Closure timespan with m suffix set correctly';

    # Test setting valid closure timespan with 'd' suffix
    $mech->get_ok('/admin/body/' . $body->id . '/test%20category');
    $mech->submit_form_ok( { with_fields => {
        closure_timespan => '90d',
        note => 'Setting closure timespan to 90 days',
    } } );
    $mech->content_contains('Values updated');
    $contact->discard_changes;
    is $contact->get_extra_metadata('closure_timespan'), '90d', 'Closure timespan with d suffix set correctly';

    # Test setting valid closure timespan without suffix (defaults to months)
    $mech->get_ok('/admin/body/' . $body->id . '/test%20category');
    $mech->submit_form_ok( { with_fields => {
        closure_timespan => '6',
        note => 'Setting closure timespan to 6 months',
    } } );
    $mech->content_contains('Values updated');
    $contact->discard_changes;
    is $contact->get_extra_metadata('closure_timespan'), '6', 'Closure timespan without suffix set correctly';

    # Test invalid format shows error
    $mech->get_ok('/admin/body/' . $body->id . '/test%20category');
    $mech->submit_form_ok( { with_fields => {
        closure_timespan => 'invalid',
        note => 'Invalid timespan format',
    } } );
    $mech->content_contains('Timespan not in correct format - must use m suffix for months or d for days');
    $contact->discard_changes;
    is $contact->get_extra_metadata('closure_timespan'), '6', 'Closure timespan unchanged after invalid input';

    # Test clearing closure timespan
    $mech->get_ok('/admin/body/' . $body->id . '/test%20category');
    $mech->submit_form_ok( { with_fields => {
        closure_timespan => '',
        note => 'Clearing closure timespan',
    } } );
    $mech->content_contains('Values updated');
    $contact->discard_changes;
    is $contact->get_extra_metadata('closure_timespan'), undef, 'Closure timespan cleared correctly';
};

subtest 'allow anonymous reporting' => sub {
    $mech->get_ok('/admin/body/' . $body->id . '/test%20category');
    $mech->content_lacks('Allow anonymous reports');
};

}; # END of override wrap

FixMyStreet::override_config {
    MAPIT_URL => 'http://mapit.uk/',
    MAPIT_TYPES => [ 'UTA' ],
    BASE_URL => 'http://www.example.org',
    ALLOWED_COBRANDS => [ "fixmystreet", "anonallowedbycategory" ],
}, sub {

subtest 'allow anonymous reporting' => sub {
    $body->discard_changes;
    $body->cobrand("anonallowedbycategory");
    $body->update;
    $mech->get_ok('/admin/body/' . $body->id . '/test%20category');
    $mech->submit_form_ok( { with_fields => {
        anonymous_allowed => 1,
        note => 'Anonymous Allowed',
    } } );
    $mech->content_contains('Values updated');
    my $contact = $body->contacts->find({ category => 'test category' });
    is $contact->get_extra_metadata('anonymous_allowed'), 1, 'Anonymous reports allowed flag set';
    $body->cobrand(undef);
    $body->update;
};

};

FixMyStreet::override_config {
    MAPIT_URL => 'http://mapit.uk/',
    MAPIT_TYPES => [ 'UTA' ],
    BASE_URL => 'http://www.example.org',
    ALLOWED_COBRANDS => "fixmystreet",
}, sub {
    subtest 'category type changing' => sub {
        my $contact = $body->contacts->find({ category => 'test category' });
        foreach ({ type => 'waste', expected => 'waste' }, { type => 'standard', expected => undef }) {
            $mech->get_ok('/admin/body/' . $body->id . '/test%20category');
            $mech->submit_form_ok( { with_fields => { type => $_->{type} } } );
            $mech->content_contains('Values updated');
            $contact->discard_changes;
            is $contact->get_extra_metadata('type'), $_->{expected}, 'Correct type set';
        }
    };
};

FixMyStreet::override_config {
    MAPIT_URL => 'http://mapit.uk/',
    MAPIT_TYPES => [ 'UTA' ],
    BASE_URL => 'http://www.example.org',
    COBRAND_FEATURES => {
        category_groups => { default => 1 },
    }
}, sub {
    subtest 'group editing works' => sub {
        $mech->get_ok('/admin/body/' . $body->id);
        $mech->follow_link_ok({ text => 'Add new category' });
        $mech->content_contains('Parent categories');

        $mech->submit_form_ok( { with_fields => {
            category   => 'grouped category',
            email      => 'test@example.com',
            note       => 'test note',
            group      => 'group a',
            non_public => undef,
            state => 'unconfirmed',
        } } );

        my $contact = $body->contacts->find({ category => 'grouped category' });
        is_deeply $contact->get_extra_metadata('group'), ['group a'], "group stored correctly";
    };

    subtest 'group can be unset' => sub {
        $mech->get_ok('/admin/body/' . $body->id);
        $mech->follow_link_ok({ text => 'Add new category' });
        $mech->content_contains('Parent categories');

        $mech->submit_form_ok( { with_fields => {
            category   => 'grouped category',
            email      => 'test@example.com',
            note       => 'test note',
            group      => undef,
            non_public => undef,
            state => 'unconfirmed',
        } } );

        my $contact = $body->contacts->find({ category => 'grouped category' });
        is $contact->get_extra_metadata('group'), undef, "group unset correctly";
    };

};

FixMyStreet::override_config {
    MAPIT_URL => 'http://mapit.uk/',
    MAPIT_TYPES => [ 'UTA' ],
    BASE_URL => 'http://www.example.org',
    COBRAND_FEATURES => {
       category_groups => { default => 1 },
    }
}, sub {
    subtest 'multi group editing works' => sub {
        $mech->get_ok('/admin/body/' . $body->id);
        $mech->follow_link_ok({ text => 'Add new category' });
        $mech->content_contains('Parent categories');

        # have to do this as a post as adding a second group requires
        # javascript
        $mech->post_ok( '/admin/body/' . $body->id . '/_add', {
            token      => $mech->form_id('category_edit')->value('token'),
            category   => 'grouped category',
            email      => 'test@example.com',
            note       => 'test note',
            'group'    => [ 'group a', 'group b'],
            non_public => undef,
            state => 'unconfirmed',
        } );

        my $contact = $body->contacts->find({ category => 'grouped category' });
        is_deeply $contact->get_extra_metadata('group'), ['group a', 'group b'], "group stored correctly";
    };
};

subtest 'check log of the above' => sub {
    $mech->get_ok('/admin/users/' . $superuser->id . '/log');
    $mech->content_contains('Added category <a href="/admin/body/' . $body->id . '/test/category">test/category</a>');
    $mech->content_contains('Edited category <a href="/admin/body/' . $body->id . '/test category">test category</a>');
    $mech->content_contains('Edited body <a href="/admin/body/' . $body->id . '">Aberdeen City Council</a>');
};

subtest 'check update disallowed message' => sub {
    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => 'bathnes',
        COBRAND_FEATURES => { updates_allowed => { bathnes => 'open' } }
    }, sub {
        $mech->get_ok('/admin/body/' . $body->id .'/test%20category');
        $mech->content_contains('even if this is unticked, only open reports can have updates left on them.');
    };
    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => 'bathnes',
        COBRAND_FEATURES => { updates_allowed => { bathnes => 'staff' } }
    }, sub {
        $mech->get_ok('/admin/body/' . $body->id .'/test%20category');
        $mech->content_contains('even if this is unticked, only staff will be able to leave updates.');
    };
    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => 'bathnes',
        COBRAND_FEATURES => { updates_allowed => { bathnes => 'reporter' } }
    }, sub {
        $mech->get_ok('/admin/body/' . $body->id .'/test%20category');
        $mech->content_contains('even if this is unticked, only the problem reporter will be able to leave updates');
    };
    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => 'bathnes',
    }, sub {
        $mech->get_ok('/admin/body/' . $body->id .'/test%20category');
        $mech->content_lacks('even if this is unticked');
    };
};

subtest 'check hardcoded contact renaming' => sub {
    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
        'ALLOWED_COBRANDS' => [ 'oxfordshire' ],
    }, sub {
        my $contact = FixMyStreet::DB->resultset('Contact')->create(
            {
                body_id => $body2->id,
                category => 'protected category',
                state => 'confirmed',
                editor => $0,
                whenedited => \'current_timestamp',
                note => 'protected contact',
                email => 'protected@example.org',
            }
        );
        $contact->set_extra_metadata( 'hardcoded', 1 );
        $contact->update;
        $mech->get_ok('/admin/body/' . $body2->id .'/protected%20category');
        $mech->content_contains( 'name="hardcoded"' );
        $mech->content_like( qr'value="protected category"[^>]*readonly's );
        $mech->submit_form_ok( { with_fields => { category => 'non protected category', note => 'rename category' } } );
        $mech->content_contains( 'protected category' );
        $mech->content_lacks( 'non protected category' );
        $mech->get('/admin/body/' . $body2->id . '/non%20protected%20category');
        is $mech->res->code, 404;

        $mech->get_ok('/admin/body/' . $body2->id .'/protected%20category');
        $mech->submit_form_ok( { with_fields => { hardcoded => 0, note => 'remove hardcoding'  } } );
        $mech->get_ok('/admin/body/' . $body2->id .'/protected%20category');
        $mech->content_unlike( qr'value="protected category"[^>]*readonly's );
        $mech->submit_form_ok( { with_fields => { category => 'non protected category', note => 'rename category'  } } );
        $mech->content_contains( 'non protected category' );
        $mech->get_ok('/admin/body/' . $body2->id . '/non%20protected%20category');
        $mech->get('/admin/body/' . $body2->id . '/protected%20category');
        is $mech->res->code, 404;

        $contact->discard_changes;
        $contact->set_extra_metadata( 'hardcoded', 1 );
        $contact->update;

        $mech->log_out_ok( $superuser->email );
        $mech->log_in_ok( $user->email );
        $mech->get_ok('/admin/body/' . $body2->id . '/non%20protected%20category');
        $mech->content_lacks( 'name="hardcoded"' );
        $user->update( { is_superuser => 1 } );
        $mech->get_ok('/admin/body/' . $body2->id . '/non%20protected%20category');
        $mech->content_contains('name="hardcoded"' );
        $user->update( { is_superuser => 0 } );
        $mech->submit_form_ok( { with_fields => { hardcoded => 0, note => 'remove hardcoding'  } } );
        $mech->content_lacks( 'name="hardcoded"' );

        $contact->discard_changes;
        is $contact->get_extra_metadata('hardcoded'), 1, "non superuser can't remove hardcoding";

        $mech->log_out_ok( $user->email );
    };
};


subtest 'check setting cobrand on body' => sub {
    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
        'ALLOWED_COBRANDS' => [ 'oxfordshire' ],
    }, sub {
        subtest 'staff user cannot see/set cobrand' => sub {
            $mech->log_in_ok( $user->email );
            $mech->get_ok('/admin/bodies');
            $mech->content_lacks('Select a cobrand');
            $mech->log_out_ok;
        };

        $mech->log_in_ok( $superuser->email );

        subtest "superuser can set body's cobrand" => sub {
            $body2->discard_changes;
            $body2->cobrand(undef);
            $body2->update;

            $mech->get_ok('/admin/body/' . $body2->id);
            $mech->content_contains('Select a cobrand');

            $mech->form_number(3);
            $mech->submit_form_ok(
                {
                    with_fields => {
                        'cobrand' => 'oxfordshire'
                    }
                }
            );
            $mech->content_contains('Values updated');

            $body2->discard_changes;
            is $body2->cobrand, 'oxfordshire';
        };

        subtest "superuser can unset body's cobrand" => sub {
            $mech->get_ok('/admin/body/' . $body2->id);
            $mech->form_number(3);
            $mech->submit_form_ok(
                {
                    with_fields => {
                        'cobrand' => undef
                    }
                }
            );
            $mech->content_contains('Values updated');

            $body2->discard_changes;
            is $body2->cobrand, undef;
        };

        subtest "cannot use the same cobrand for multiple bodies" => sub {
            $body2->cobrand('oxfordshire');
            $body2->update;

            $mech->get_ok('/admin/body/' . $body->id);
            $mech->form_number(3);
            $mech->submit_form_ok(
                {
                    with_fields => {
                        'cobrand' => 'oxfordshire'
                    }
                }
            );
            $mech->content_lacks('Values updated');
            $mech->content_contains('This cobrand is already assigned to another body: Oxfordshire County Council');

            $body->discard_changes;
            is $body->cobrand, undef;
            $body2->discard_changes;
            is $body2->cobrand, 'oxfordshire';
        };
    };
};

subtest 'check parishes work on Bucks okay' => sub {
    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => [ "buckinghamshire" ],
    }, sub {
        $mech->get_ok('/admin/body/' . $bucks->id);
        # Form has 2508 and 53319 in it, unselected
        $mech->submit_form_ok({ with_fields => { area_ids => 53319 } });
        # Body now has 2217 (kept) and 53319
        is $bucks->body_areas->count, 2;
    };

    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => [ "fixmystreet" ],
    }, sub {
        $mech->get_ok('/admin/body/' . $bucks->id);
        # Form has only 2508 in it, unselected
        $mech->submit_form_ok({ with_fields => { name => 'Bucks' } });
        # Body has 2217 and 53319 kept
        is $bucks->body_areas->count, 2;
    };
};

subtest 'check editing a contact when category groups disabled does not remove existing groups' => sub {
    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
        MAPIT_TYPES => [ 'UTA' ],
        COBRAND_FEATURES => {
           category_groups => { default => 1 },
        }
    }, sub {
        $mech->get_ok( '/admin/body/' . $body->id . '/_add');
        $mech->post_ok( '/admin/body/' . $body->id . '/_add', {
            token      => $mech->form_id('category_edit')->value('token'),
            category   => 'group editing test category',
            email      => 'test@example.com',
            note       => 'test note',
            'group'    => [ 'group 1', 'group 2'],
            non_public => undef,
            state => 'unconfirmed',
        } );
        my $contact = $body->contacts->find({ category => 'group editing test category' });
        is_deeply $contact->get_extra_metadata('group'), ['group 1', 'group 2'], "groups set-up correctly";
    };
    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
        MAPIT_TYPES => [ 'UTA' ],
    }, sub {
        $mech->get_ok('/admin/body/' . $body->id .'/group%20editing%20test%20category');
        $mech->content_lacks('Parent categories');
        $mech->submit_form_ok( { with_fields => {
            email => 'test2@example.com',
        } } );
        my $contact = $body->contacts->find({ category => 'group editing test category' });
        is_deeply $contact->get_extra_metadata('group'), ['group 1', 'group 2'], "groups not removed after edit";
    };
};

done_testing();
