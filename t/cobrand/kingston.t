use CGI::Simple;
use Test::MockModule;
use Test::MockTime qw(:all);
use Test::Warn;
use DateTime;
use JSON::MaybeXS;
use Test::Output;
use FixMyStreet::TestMech;
use FixMyStreet::SendReport::Open311;
use FixMyStreet::Script::Reports;
use FixMyStreet::Script::Alerts;
use Open311::PostServiceRequestUpdates;
use List::Util 'any';
use Regexp::Common 'URI';
my $mech = FixMyStreet::TestMech->new;

# disable info logs for this test run
FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

# Create test data
my $user = $mech->create_user_ok( 'kingston@example.com', name => 'Kingston' );
my $body = $mech->create_body_ok( 2480, 'Kingston upon Thames Council', {
    can_be_devolved => 1, send_extended_statuses => 1, comment_user => $user,
    send_method => 'Open311', endpoint => 'http://endpoint.example.com', jurisdiction => 'FMS', api_key => 'test', send_comments => 1
}, {
    cobrand => 'kingston',
});

foreach ([ 1638 => 'Garden Subscription' ]) {
    $mech->create_contact_ok(
        body => $body,
        email => $_->[0],
        category => $_->[1],
        send_method => 'Open311',
        endpoint => 'waste-endpoint',
        extra => { type => 'waste' },
        group => ['Waste'],
    );
}

package SOAP::Result;
sub result { return $_[0]->{result}; }
sub new { my $c = shift; bless { @_ }, $c; }

package main;

subtest 'updating of waste reports' => sub {
    my $integ = Test::MockModule->new('SOAP::Lite');
    $integ->mock(call => sub {
        my ($cls, @args) = @_;
        my $method = $args[0]->name;
        if ($method eq 'GetEvent') {
            my ($key, $type, $value) = ${$args[3]->value}->value;
            my $external_id = ${$value->value}->value->value;
            my ($waste, $event_state_id, $resolution_code) = split /-/, $external_id;
            return SOAP::Result->new(result => {
                Guid => $external_id,
                EventStateId => $event_state_id,
                EventTypeId => '1638',
                LastUpdatedDate => { OffsetMinutes => 60, DateTime => '2020-06-24T14:00:00Z' },
                ResolutionCodeId => $resolution_code,
            });
        } elsif ($method eq 'GetEventType') {
            return SOAP::Result->new(result => {
                Workflow => { States => { State => [
                    { CoreState => 'New', Name => 'New', Id => 15001 },
                    { CoreState => 'Pending', Name => 'Unallocated', Id => 15002 },
                    { CoreState => 'Pending', Name => 'Allocated to Crew', Id => 15003 },
                ] } },
            });
        } else {
            is $method, 'UNKNOWN';
        }
    });

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'kingston',
        COBRAND_FEATURES => {
            echo => { kingston => { url => 'https://www.example.org/' } },
            waste => { kingston => 1 }
        },
    }, sub {
        my @reports = $mech->create_problems_for_body(2, $body->id, 'Garden Subscription', {
            category => 'Garden Subscription',
            cobrand_data => 'waste',
        });
        $reports[1]->update({ external_id => 'something-else' }); # To test loop
        my $report = $reports[0];
        my $cobrand = FixMyStreet::Cobrand::Kingston->new;

        $report->update({ external_id => 'waste-15001-' });
        stdout_like {
            $cobrand->waste_fetch_events({ verbose => 1 });
        } qr/Fetching data for report/;
        $report->discard_changes;
        is $report->comments->count, 0, 'No new update';
        is $report->state, 'confirmed', 'No state change';

        $report->update({ external_id => 'waste-15002-' });
        stdout_like {
            $cobrand->waste_fetch_events({ verbose => 1 });
        } qr/Updating report to state investigating, Unallocated/;
        $report->discard_changes;
        is $report->comments->count, 1, 'A new update';
        my $update = $report->comments->first;
        is $update->text, 'Unallocated';
        is $report->state, 'investigating', 'A state change';

        $report->update({ external_id => 'waste-15003-' });
        stdout_like {
            $cobrand->waste_fetch_events({ verbose => 1 });
        } qr/Fetching data for report/;
        $report->discard_changes;
        is $report->comments->count, 1, 'No new update';
        is $report->state, 'investigating', 'State unchanged';
    };
};

done_testing();
