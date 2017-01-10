use strict;
use warnings;
use Test::More;

use CGI::Simple;
use FixMyStreet::TestMech;
my $mech = FixMyStreet::TestMech->new;

# Create test data
my $user = $mech->create_user_ok( 'bromley@example.com' );
my $body = $mech->create_body_ok( 2482, 'Bromley Council', id => 2482 );
my $contact = $mech->create_contact_ok(
    body_id => $body->id,
    category => 'Other',
    email => 'LIGHT',
);
$contact->set_extra_metadata(id_field => 'service_request_id_ext');
$contact->set_extra_fields(
    { code => 'easting', datatype => 'number', },
    { code => 'northing', datatype => 'number', },
    { code => 'service_request_id_ext', datatype => 'number', },
);
$contact->update;

my @reports = $mech->create_problems_for_body( 1, $body->id, 'Test', {
    cobrand => 'bromley',
    user => $user,
});
my $report = $reports[0];

for my $update ('in progress', 'unable to fix') {
    FixMyStreet::DB->resultset('Comment')->find_or_create( {
        problem_state => $update,
        problem_id => $report->id,
        user_id    => $user->id,
        name       => 'User',
        mark_fixed => 'f',
        text       => "This update marks it as $update",
        state      => 'confirmed',
        confirmed  => 'now()',
        anonymous  => 'f',
    } );
}

# Test Bromley special casing of 'unable to fix'
$mech->get_ok( '/report/' . $report->id );
$mech->content_contains( 'marks it as in progress' );
$mech->content_contains( 'marked as in progress' );
$mech->content_contains( 'marks it as unable to fix' );
$mech->content_contains( 'marked as no further action' );

subtest 'testing special Open311 behaviour', sub {
    $report->set_extra_fields();
    $report->update;
    $body->update( { send_method => 'Open311', endpoint => 'http://bromley.endpoint.example.com', jurisdiction => 'FMS', api_key => 'test' } );
    my $test_data;
    FixMyStreet::override_config {
        STAGING_FLAGS => { send_reports => 1 },
        ALLOWED_COBRANDS => [ 'fixmystreet', 'bromley' ],
    }, sub {
        $test_data = FixMyStreet::DB->resultset('Problem')->send_reports();
    };
    $report->discard_changes;
    ok $report->whensent, 'Report marked as sent';
    is $report->send_method_used, 'Open311', 'Report sent via Open311';
    is $report->external_id, 248, 'Report has right external ID';

    my $req = $test_data->{test_req_used};
    my $c = CGI::Simple->new($req->content);
    is $c->param('attribute[easting]'), 529025, 'Request had easting';
    is $c->param('attribute[northing]'), 179716, 'Request had northing';
    is $c->param('attribute[service_request_id_ext]'), $report->id, 'Request had correct ID';
    is $c->param('jurisdiction_id'), 'FMS', 'Request had correct jurisdiction';
};

for my $test (
    {
        cobrand => 'bromley',
        fields => {
            submit_update   => 1,
            rznvy           => 'unregistered@example.com',
            update          => 'Update from an unregistered user',
            add_alert       => undef,
            first_name            => 'Unreg',
            last_name            => 'User',
            fms_extra_title => 'DR',
            may_show_name   => undef,
        }
    },
    {
        cobrand => 'fixmystreet',
        fields => {
            submit_update   => 1,
            rznvy           => 'unregistered@example.com',
            update          => 'Update from an unregistered user',
            add_alert       => undef,
            name            => 'Unreg User',
            fms_extra_title => 'DR',
            may_show_name   => undef,
        }
    },
)
{
    subtest 'check Bromley update emails via ' . $test->{cobrand} . ' cobrand are correct' => sub {
        $mech->log_out_ok();
        $mech->clear_emails_ok();

        my $report_id = $report->id;

        FixMyStreet::override_config {
            ALLOWED_COBRANDS => [ $test->{cobrand} ],
        }, sub {
            $mech->get_ok("/report/$report_id");
            $mech->submit_form_ok(
                {
                    with_fields => $test->{fields}
                },
                'submit update'
            );
        };
        $mech->content_contains('Nearly done! Now check your email');

        my $body = $mech->get_text_body_from_email;
        like $body, qr/This update will be sent to Bromley Council/i, "Email indicates problem will be sent to Bromley";
        unlike $body, qr/Note that we do not send updates to/i, "Email does not say updates aren't sent to Bromley";

        my $unreg_user = FixMyStreet::App->model( 'DB::User' )->find( { email => 'unregistered@example.com' } );

        ok $unreg_user, 'found user';

        $mech->delete_user( $unreg_user );
    };
}

# Clean up
$mech->delete_user($user);
$mech->delete_body($body);
done_testing();
