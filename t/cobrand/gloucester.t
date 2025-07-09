use FixMyStreet::Cobrand::Gloucester;
use FixMyStreet::Script::Reports;
use FixMyStreet::TestMech;
use Test::Deep;
use Test::MockModule;

FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $mech    = FixMyStreet::TestMech->new;
my $cobrand = Test::MockModule->new('FixMyStreet::Cobrand::UKCouncils');
$cobrand->mock(
    '_fetch_features',
    sub {
        return [
            {   properties => { itemId => 'an_asset_id' },
                geometry   => {
                    type        => 'LineString',
                    coordinates =>
                        [ [ -2.24586, 51.86506 ], [ -2.24586, 51.86506 ], ],
                }
            }
        ];
    },
);

my $body = $mech->create_body_ok(
    2325,
    'Gloucester City Council',
    {   send_method  => 'Open311',
        api_key      => 'key',
        endpoint     => 'endpoint',
        jurisdiction => 'jurisdiction',
        cobrand => 'gloucester',
        can_be_devolved => 1,
    },
);

# Email only
my $graffiti = $mech->create_contact_ok(
    body_id  => $body->id,
    category => 'Graffiti',
    email    => 'graffiti@gloucester.dev',
    send_method => 'Email',
);

# Open311 only
my $flytipping = $mech->create_contact_ok(
    body_id  => $body->id,
    category => 'Flytipping',
    email    => 'Regular_fly-tipping_(not_witnessed_and_no_evidence_likely)',
);

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'gloucester' ],
    MAPIT_URL        => 'http://mapit.uk/',
    STAGING_FLAGS => { send_reports => 1, skip_checks => 0 },
    COBRAND_FEATURES => {
        open311_email => {
            gloucester => {
                'Dog fouling' => 'enviro-crime@gloucester.dev'
            }
        },
        asset_layers => { gloucester => [
            {
                http_options => { params => { layer => 'plots' } },
                asset_category => ['Flytipping'],
            }
        ] },
    },
}, sub {
    ok $mech->host('gloucester'), 'change host to gloucester';
    $mech->get_ok('/');
    $mech->content_like(qr/Enter a nearby Gloucester postcode/);

    subtest 'Send report' => sub {
        subtest 'Email only' => sub {
            $mech->get('/report/new?longitude=-2.2458&latitude=51.86506');
            $mech->follow_link_ok( { text_regex => qr/skip this step/i } );
            $mech->submit_form_ok(
                {   button      => 'submit_register',
                    with_fields => {
                        category => 'Graffiti',
                        detail   => 'Test report details',
                        title    => 'Test Report',
                        name     => 'Test User',
                        username_register => 'test@example.org',
                    }
                }
            );
            like $mech->text, qr/Nearly done! Now check your email/;

            my $report
                = FixMyStreet::DB->resultset('Problem')->order_by('-id')
                ->first;
            $report->confirm;
            $report->update;
            $mech->clear_emails_ok; # Clear initial confirmation email
            FixMyStreet::Script::Reports::send();
            $report->discard_changes;

            is $report->send_state,  'sent', 'sent successfully';
            is $report->external_id, undef, 'no external ID';
            is $report->get_extra_field_value('did_you_witness'), undef,
                'no witness question';
            is $report->get_extra_metadata('extra_email_sent'), undef,
                'no extra_email_sent';

            $mech->email_count_is(1), 'one email sent';
        };

        subtest 'Open311 only' => sub {
            $mech->delete_problems_for_body($body->id);
            $mech->clear_emails_ok;

            $mech->get('/report/new?longitude=-2.2458&latitude=51.86506');
            $mech->follow_link_ok( { text_regex => qr/skip this step/i } );
            $mech->submit_form_ok(
                {   button      => 'submit_register',
                    with_fields => {
                        category => 'Flytipping',
                        detail   => 'Test report details',
                        title    => 'Test Report',
                        name     => 'Test User',
                        username_register => 'test@example.org',
                    }
                }
            );
            like $mech->text, qr/Nearly done! Now check your email/;

            my $report
                = FixMyStreet::DB->resultset('Problem')->order_by('-id')
                ->first;
            $report->confirm;
            $report->update;
            $mech->clear_emails_ok; # Clear initial confirmation email
            FixMyStreet::Script::Reports::send();
            $report->discard_changes;


            is $report->send_state,  'sent', 'sent successfully';
            is $report->external_id, '248', 'has external ID';
            is $report->get_extra_field_value('did_you_witness'), undef,
                'no witness question';
            is $report->get_extra_metadata('extra_email_sent'), undef,
                'no extra_email_sent';
            is $report->get_extra_field_value('asset_resource_id'), 'an_asset_id',
                'asset_resource_id set';

            $mech->email_count_is(0), 'no email sent';
        };
    };
};

done_testing();
