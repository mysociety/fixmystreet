use FixMyStreet::TestMech;
use Capture::Tiny 'capture_stderr';

FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $mech = FixMyStreet::TestMech->new;

my $superuser = $mech->create_user_ok('superuser@example.com', name => 'Super User', is_superuser => 1);

$mech->log_in_ok($superuser->email);

FixMyStreet::override_config {
    ALLOWED_COBRANDS => ['fixmystreet'],
}, sub {
    subtest 'can add new config entry' => sub {
        $mech->get_ok('/admin/config');
        $mech->submit_form_ok({
            with_fields => {
                'new-config-key' => 'test_config_key',
                'new-config-value' => '["value1", "value2"]',
            }
        });
        $mech->content_contains('Updated!');
        $mech->content_contains('test_config_key');

        my $value = FixMyStreet::DB->resultset("Config")->get('test_config_key');
        is_deeply $value, ['value1', 'value2'], 'config value correct';
    };

    subtest 'cannot add duplicate config key' => sub {
        $mech->get_ok('/admin/config');

        # Suppress expected transaction rollback warning
        capture_stderr {
            $mech->submit_form_ok({
                with_fields => {
                    'new-config-key' => 'test_config_key',
                    'new-config-value' => '"different_value"',
                }
            });
        };
        $mech->content_contains('already exists');
        $mech->content_lacks('Updated!');

        $mech->content_contains('value="test_config_key"', 'key preserved in form');
        $mech->content_contains('&quot;different_value&quot;', 'value preserved in form');

        my $value = FixMyStreet::DB->resultset("Config")->get('test_config_key');
        is_deeply $value, ['value1', 'value2'], 'original config value unchanged';
    };

    subtest 'whitespace is trimmed from new config key' => sub {
        $mech->get_ok('/admin/config');
        $mech->submit_form_ok({
            with_fields => {
                'new-config-key' => '  trimmed_key  ',
                'new-config-value' => 'true',
            }
        });
        $mech->content_contains('Updated!');

        my $value = FixMyStreet::DB->resultset("Config")->get('trimmed_key');
        is $value, 1, 'JSON true decoded to 1';
    };

    subtest 'error shown for invalid JSON value' => sub {
        $mech->get_ok('/admin/config');

        capture_stderr {
            $mech->submit_form_ok({
                with_fields => {
                    'new-config-key' => 'invalid_json_key',
                    'new-config-value' => 'not valid json {',
                }
            });
        };
        $mech->content_contains('Not a valid JSON string');
        $mech->content_lacks('Updated!');

        $mech->content_contains('value="invalid_json_key"', 'key preserved in form');
        $mech->content_contains('not valid json {', 'value preserved in form');

        my $value = FixMyStreet::DB->resultset("Config")->get('invalid_json_key');
        ok !$value, 'invalid config entry not created';
    };

    subtest 'add form shown even when no config entries exist' => sub {
        # Delete all config entries
        FixMyStreet::DB->resultset('Config')->delete;

        $mech->get_ok('/admin/config');
        $mech->content_contains('Database site configuration');
        $mech->content_contains('new-config-key');
        $mech->content_contains('new-config-value');
        $mech->content_contains('name="new-config-key"');

        # Can still add entries
        $mech->submit_form_ok({
            with_fields => {
                'new-config-key' => 'first_config',
                'new-config-value' => '42',
            }
        });
        $mech->content_contains('Updated!');
        $mech->content_contains('first_config');

        my $value = FixMyStreet::DB->resultset("Config")->get('first_config');
        is $value, 42, 'numeric value correct';
    };

    subtest 'can add config with complex JSON object' => sub {
        $mech->get_ok('/admin/config');
        $mech->submit_form_ok({
            with_fields => {
                'new-config-key' => 'complex_config',
                'new-config-value' => '{"nested": {"key": "value"}, "array": [1, 2, 3]}',
            }
        });
        $mech->content_contains('Updated!');

        my $value = FixMyStreet::DB->resultset("Config")->get('complex_config');
        is_deeply $value, { nested => { key => 'value' }, array => [1, 2, 3] },
            'complex JSON value correctly stored';
    };

    subtest 'can edit existing config entry' => sub {
        FixMyStreet::DB->resultset("Config")->set('editable_config', ['item1', 'item2']);

        $mech->get_ok('/admin/config');
        $mech->content_contains('editable_config');
        $mech->content_contains('item1, item2');  # Array displayed as comma-separated

        # Edit the config value via the form
        $mech->submit_form_ok({
            with_fields => {
                'db-config-editable_config' => '["updated_item", "new_item"]',
            }
        });
        $mech->content_contains('Updated!');

        # Verify the change persisted
        my $value = FixMyStreet::DB->resultset("Config")->get('editable_config');
        is_deeply $value, ['updated_item', 'new_item'], 'config value was updated';

        # Verify the new value is displayed
        $mech->content_contains('updated_item, new_item');
    };
};

done_testing();
