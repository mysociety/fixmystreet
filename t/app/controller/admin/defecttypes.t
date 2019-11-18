use FixMyStreet::TestMech;

my $mech = FixMyStreet::TestMech->new;

FixMyStreet::override_config { ALLOWED_COBRANDS => ['bromley'], }, sub {
    subtest 'check defecttypes menu not available' => sub {
        my $body = $mech->create_body_ok( 2482, 'Bromley Council' );

        my $user = $mech->create_user_ok(
            'bromley@example.com',
            name => 'Test User',
            from_body => $body
        );

        $mech->log_in_ok( $user->email );

        $mech->get_ok('/admin');
        $mech->content_lacks('Defect Types');

        is $mech->get('/admin/defecttypes')->code, 404, '404 if no permission';
        is $mech->get('/admin/defecttypes/' . $body->id)->code, 404, '404 if no permission';

        $mech->log_out_ok();
    };
};

FixMyStreet::override_config { ALLOWED_COBRANDS => ['oxfordshire'], }, sub {

    my $body = $mech->create_body_ok( 2237, 'Oxfordshire County Council' );

    subtest 'check defect types menu available to superusers' => sub {
        my $user = $mech->create_user_ok(
            'superuser@example.com',
            name => 'Test Superuser',
            is_superuser => 1
        );

        $mech->log_in_ok( $user->email );
        $mech->get_ok('/admin');
        $mech->content_contains('Defect Types');
        $mech->get_ok('/admin/defecttypes');
        $mech->log_out_ok();
    };

    my $user = $mech->create_user_ok(
        'oxford@example.com',
        name => 'Test User',
        from_body => $body
    );

    $mech->log_in_ok( $user->email );

    my $contact = $mech->create_contact_ok(
        body_id => $body->id,
        category => 'Traffic lights',
        email => 'lights@example.com'
    );

    subtest 'check defecttypes menu not available without permissions' => sub {
        $mech->get_ok('/admin');
        $mech->content_lacks('Defect Types');

        is $mech->get('/admin/defecttypes')->code, 404, '404 if no permission';
        is $mech->get('/admin/defecttypes/' . $body->id)->code, 404, '404 if no permission';
    };

    $user->user_body_permissions->create( {
        body => $body,
        permission_type => 'defect_type_edit',
    } );

    subtest 'check defecttypes menu available with permissions' => sub {
        $mech->get_ok('/admin');
        $mech->content_contains('Defect Types');
        $mech->get_ok('/admin/defecttypes');
        is $mech->res->previous->code, 302, 'index redirects...';
        is $mech->uri->path, '/admin/defecttypes/' . $body->id, '...to body page';
    };

    subtest 'check missing defect type is 404' => sub {
        is $mech->get( '/admin/defecttypes/' . $body->id . '/299')->code, 404;
    };

    subtest 'check adding a defect type' => sub {
        $mech->get_ok( '/admin/defecttypes/' . $body->id . '/new' );

        $mech->content_contains('Traffic lights');

        $mech->submit_form_ok( {
                with_fields => {
                    name => 'A defect',
                    description => 'This is a new defect',
                } } );

        $mech->content_contains('New defect');
    };

    subtest 'check editing a defect type' => sub {
        my $defect = FixMyStreet::DB->resultset('DefectType')->search( {
                name => 'A defect',
                body_id => $body->id
            } )->first;

        $mech->get_ok( '/admin/defecttypes/' . $body->id . '/' . $defect->id );

        $mech->submit_form_ok( {
                with_fields => {
                    name => 'Updated defect',
                    description => 'This is a new defect',
                }
            },
            'submitted form'
        );

        $mech->content_lacks('A defect');
        $mech->content_contains('Updated defect');

        my $defects = FixMyStreet::DB->resultset('DefectType')->search( {
            body_id => $body->id
        } );

        is $defects->count, 1, 'only 1 defect';
    };

    subtest 'check adding a category to a defect' => sub {
        my $defect = FixMyStreet::DB->resultset('DefectType')->search( {
                name => 'Updated defect',
                body_id => $body->id
            } )->first;

        is $defect->contact_defect_types->count, 0,
          'defect has no contact types';

        $mech->get_ok( '/admin/defecttypes/' . $body->id . '/' . $defect->id );

        $mech->submit_form_ok( {
                with_fields => {
                    name => 'Updated defect',
                    description => 'This is a new defect',
                    categories => [ $contact->id ],
                }
            },
            'submitted form'
        );

        $mech->content_contains('Traffic lights');

        $defect->discard_changes;
        is $defect->contact_defect_types->count, 1, 'defect has a contact type';
        is $defect->contact_defect_types->first->contact->category,
          'Traffic lights', 'defect has correct contact type';
    };

    subtest 'check removing category from a defect' => sub {
        my $defect = FixMyStreet::DB->resultset('DefectType')->search( {
                name => 'Updated defect',
                body_id => $body->id
            } )->first;

        is $defect->contact_defect_types->count, 1,
          'defect has one contact types';

        $mech->get_ok( '/admin/defecttypes/' . $body->id . '/' . $defect->id );

        $mech->submit_form_ok( {
                with_fields => {
                    name => 'Updated defect',
                    description => 'This is a new defect',
                    categories => '',
                }
            },
            'submitted form'
        );

        $mech->content_lacks('Traffic lights');

        $defect->discard_changes;
        is $defect->contact_defect_types->count, 0,
          'defect has no contact type';
    };

    subtest 'check adding codes to a defect' => sub {
        my $defect = FixMyStreet::DB->resultset('DefectType')->search( {
                name => 'Updated defect',
                body_id => $body->id
            } )->first;

        $mech->get_ok( '/admin/defecttypes/' . $body->id . '/' . $defect->id );

        $mech->submit_form_ok( {
                with_fields => {
                    name => 'Updated defect',
                    description => 'This is a new defect',
                    'extra[activity_code]' => 1,
                    'extra[defect_code]' => 2,
                }
            },
            'submitted form'
        );

        $defect->discard_changes;
        is_deeply $defect->get_extra_metadata,
          { activity_code => 1, defect_code => 2 }, 'defect codes set';
    };
};

done_testing();
