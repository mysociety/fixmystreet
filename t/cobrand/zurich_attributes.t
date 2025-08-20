use FixMyStreet::TestMech;

my $mech = FixMyStreet::TestMech->new;

use_ok 'FixMyStreet::App', 'FixMyStreet::Cobrand::Zurich';

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'zurich',
    MAPIT_URL => 'http://mapit.uk/',
}, sub {
    my $zurich = $mech->create_body_ok(1, 'Zurich');
    my $division = $mech->create_body_ok( 423017, 'Division 1', {
        parent => $zurich->id, send_method => 'Zurich', endpoint => 'division@example.org' } );
    my $division_id = $division->id;

    # In Zurich, users from the parent body are superusers
    my $superuser = $mech->create_user_ok('super@example.com', name => 'Super User', from_body => $zurich->id);
    my $division_user = $mech->create_user_ok('division@example.com', name => 'Division User', from_body => $division->id);
    $division_user->user_body_permissions->create({ body => $division, permission_type => 'category_edit' });

    # Create a subdivision for SDM testing
    my $subdivision = $mech->create_body_ok( 423018, 'Subdivision A', {
        parent => $division->id, send_method => 'Zurich', endpoint => 'subdivision@example.org' } );
    my $sdm_user = $mech->create_user_ok('sdm@example.com', name => 'SDM User', from_body => $subdivision->id);

    subtest 'Default hierarchical attributes structure' => sub {
        $mech->log_in_ok($superuser->email);
        $mech->get_ok("/admin/body/$division_id/attributes");

        $mech->content_contains('Geschäftsbereich');
        $mech->content_contains('Objekt');
        $mech->content_contains('Kategorie');

        $mech->content_contains('new_Objekt_parent');
        $mech->content_contains('new_Kategorie_parent');
    };

    subtest 'Adding new hierarchical attributes' => sub {
        $mech->log_in_ok($superuser->email);

        $mech->get_ok("/admin/body/$division_id/attributes");
        $mech->submit_form_ok({
            with_fields => {
                'new_Geschäftsbereich_name' => 'Test Business Area',
            }
        });
        $mech->content_contains('Hierarchical attributes updated');
        $mech->submit_form_ok({
            with_fields => {
                'new_Geschäftsbereich_name' => 'Second Business Area',
            }
        });

        $mech->get_ok("/admin/body/$division_id/attributes");
        $mech->content_contains('Test Business Area');

        $mech->submit_form_ok({
            with_fields => {
                'new_Objekt_name' => 'Test Object',
                'new_Objekt_parent' => '1', # First entry has ID 1
            }
        });
        $mech->content_contains('Hierarchical attributes updated');

        $mech->get_ok("/admin/body/$division_id/attributes");
        $mech->content_contains('Test Object');

        $mech->submit_form_ok({
            with_fields => {
                'new_Kategorie_name' => 'Test Category',
                'new_Kategorie_parent' => '1',
            }
        });
        $mech->content_contains('Hierarchical attributes updated');

        $mech->get_ok("/admin/body/$division_id/attributes");
        $mech->content_contains('Test Category');
    };

    subtest 'Validation errors' => sub {
        $mech->log_in_ok($superuser->email);

        $mech->get_ok("/admin/body/$division_id/attributes");
        $mech->submit_form_ok({
            with_fields => {
                'new_Geschäftsbereich_name' => '',
            }
        });
        $mech->content_lacks('Hierarchical attributes updated');

        $mech->submit_form_ok({
            with_fields => {
                'new_Objekt_name' => 'Test Object Without Parent',
                'new_Objekt_parent' => '',
            }
        });
        $mech->content_contains('Parent is required');

        $mech->submit_form_ok({
            with_fields => {
                'new_Geschäftsbereich_name' => 'Test Business Area', # Already exists
            }
        });
        $mech->content_contains('An entry with this name already exists');

        $mech->submit_form_ok({
            with_fields => {
                'new_Objekt_name' => 'Test Object',
                'new_Objekt_parent' => '1', # First entry has ID 1
            }
        });
        $mech->content_contains('An entry with this name already exists');

        $mech->submit_form_ok({
            with_fields => {
                'new_Objekt_name' => 'Test Object',
                'new_Objekt_parent' => '2',
            }
        });
        $mech->content_contains('Hierarchical attributes updated');
    };

    subtest 'Editing existing entry names' => sub {
        $mech->log_in_ok($superuser->email);

        $mech->get_ok("/admin/body/$division_id/attributes");
        $mech->content_contains('Test Business Area');
        $mech->submit_form_ok({
            with_fields => {
                'Geschäftsbereich_1_name' => 'Updated Name',
            }
        });
        $mech->content_contains('Hierarchical attributes updated');

        $mech->get_ok("/admin/body/$division_id/attributes");
        $mech->content_contains('Updated Name');
        $mech->content_lacks('Test Business Area');

        $mech->submit_form_ok({
            with_fields => {
                'Geschäftsbereich_1_name' => '',
            }
        });
        $mech->content_contains('Name cannot be empty');

        $mech->submit_form_ok({
            with_fields => {
                'new_Geschäftsbereich_name' => 'Another Area',
            }
        });
        $mech->submit_form_ok({
            with_fields => {
                'Geschäftsbereich_1_name' => 'Another Area',
            }
        });
        $mech->content_contains('An entry with this name already exists');
    };

    subtest 'Invalid parent validation' => sub {
        $mech->log_in_ok($superuser->email);
        $mech->get_ok("/admin/body/$division_id/attributes");

        $mech->submit_form_ok({
            with_fields => {
                'new_Objekt_name' => 'Test Object Invalid Parent',
                'new_Objekt_parent' => '999',
            }
        });
        $mech->content_contains('Invalid parent selected');

        $mech->submit_form_ok({
            with_fields => {
                'new_Geschäftsbereich_name' => 'Parent to Delete',
            }
        });

        $mech->get_ok("/admin/body/$division_id/attributes");
        $mech->submit_form_ok({
            with_fields => {
                'Geschäftsbereich_3_deleted' => 1,
            }
        });
        $mech->content_contains('Hierarchical attributes updated');

        # Deleted parent should be invalid
        $mech->submit_form_ok({
            with_fields => {
                'new_Objekt_name' => 'Test Object Invalid Parent',
                'new_Objekt_parent' => '3',
            }
        });
        $mech->content_contains('Invalid parent selected');
    };

    subtest 'Deleting attributes with child validation' => sub {
        $mech->log_in_ok($superuser->email);
        $mech->get_ok("/admin/body/$division_id/attributes");

        $mech->submit_form_ok({
            with_fields => {
                'Geschäftsbereich_1_deleted' => 1,
            }
        });
        $mech->content_contains('Cannot delete entry that has active child entries');

        $mech->submit_form_ok({
            with_fields => {
                'Objekt_1_deleted' => 1,
                'Kategorie_1_deleted' => 1,
            }
        });
        $mech->content_contains('Hierarchical attributes updated');

        $mech->submit_form_ok({
            with_fields => {
                'Geschäftsbereich_1_deleted' => 1,
            }
        });
        $mech->content_contains('Hierarchical attributes updated');
    };

    subtest 'Report hierarchical attributes functionality' => sub {
        $mech->log_in_ok($superuser->email);
        $mech->get_ok("/admin/body/$division_id/attributes");

        $mech->submit_form_ok({
            with_fields => {
                'new_Geschäftsbereich_name' => 'Test Geschäftsbereich',
            }
        });

        $mech->submit_form_ok({
            with_fields => {
                'new_Objekt_name' => 'Test Objekt',
                'new_Objekt_parent' => '1',
            }
        });

        $mech->submit_form_ok({
            with_fields => {
                'new_Kategorie_name' => 'Test Kategorie',
                'new_Kategorie_parent' => '1',
            }
        });

        my ($problem) = $mech->create_problems_for_body(1, $division->id, 'Test Problem');
        $problem->update({ state => 'confirmed' });

        $mech->get_ok("/admin/report_edit/" . $problem->id);
        $mech->content_contains('Hierarchical Attributes');
        $mech->content_contains('hierarchical_geschaftsbereich');
        $mech->content_contains('hierarchical_objekt');
        $mech->content_contains('hierarchical_kategorie');
        $mech->content_contains('Test Geschäftsbereich');

        $mech->submit_form_ok({
            with_fields => {
                'submit' => '1',
                'new_internal_note' => 'Test note without attributes',
            }
        });
        $mech->content_contains('Please select all hierarchical attributes before saving');

        $mech->submit_form_ok({
            with_fields => {
                'submit' => '1',
                'hierarchical_geschaftsbereich' => '1',
                'hierarchical_objekt' => '1',
                'hierarchical_kategorie' => '1',
                'new_internal_note' => 'Test note with attributes',
            }
        });
        $mech->content_like(qr/Updated|message-updated/);

        $problem->discard_changes;
        my $saved_attributes = $problem->get_extra_metadata('hierarchical_attributes');
        ok($saved_attributes, 'Hierarchical attributes were saved');
        is($saved_attributes->{geschaftsbereich}, '1', 'Geschäftsbereich saved correctly');
        is($saved_attributes->{objekt}, '1', 'Objekt saved correctly');
        is($saved_attributes->{kategorie}, '1', 'Kategorie saved correctly');

        my $external_body = $mech->create_body_ok(999, 'External Body');
        my $external_contact = $mech->create_contact_ok(
            body_id => $external_body->id,
            category => 'External Category',
            email => 'external@example.com',
        );

        $mech->get_ok("/admin/report_edit/" . $problem->id);
        $mech->submit_form_ok({
            with_fields => {
                'submit' => '1',
                'state' => 'confirmed',
                'category' => 'External Category',
                'hierarchical_geschaftsbereich' => '1',
                'hierarchical_objekt' => '1',
                'hierarchical_kategorie' => '1',
            }
        });

        $problem->discard_changes;
        my $cleared_attributes = $problem->get_extra_metadata('hierarchical_attributes');
        ok(!$cleared_attributes, 'Hierarchical attributes cleared on body reassignment');
    };

    subtest 'SDM view of hierarchical attributes' => sub {
        $mech->log_in_ok($sdm_user->email);

        # Create a problem with hierarchical attributes for the division (parent body)
        my ($problem) = $mech->create_problems_for_body(1, $division->id, 'SDM Test Problem');
        $problem->update({ state => 'in progress' });
        $problem->set_extra_metadata('hierarchical_attributes', {
            geschaftsbereich => '1',
            objekt => '1',
            kategorie => '1',
        });
        $problem->update;

        # SDM should see attributes but not be able to edit them
        $mech->get_ok("/admin/report_edit/" . $problem->id);
        $mech->content_contains('Hierarchical Attributes');
        $mech->content_contains('Updated Name');  # Name was changed in earlier test
        $mech->content_contains('Test Object');
        $mech->content_contains('Test Category');

        # Should not contain editable dropdowns
        $mech->content_lacks('hierarchical_geschaftsbereich');
        $mech->content_lacks('Select Geschäftsbereich');
    };

};

done_testing();
