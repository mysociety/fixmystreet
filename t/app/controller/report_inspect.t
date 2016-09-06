use strict;
use warnings;
use Test::More;

use FixMyStreet::TestMech;

my $mech = FixMyStreet::TestMech->new;

my $brum = $mech->create_body_ok(2514, 'Birmingham City Council');
my $oxon = $mech->create_body_ok(2237, 'Oxfordshire County Council');
my $contact = $mech->create_contact_ok( body_id => $oxon->id, category => 'Cows', email => 'cows@example.net' );
my $rp = FixMyStreet::DB->resultset("ResponsePriority")->create({
    body => $oxon,
    name => 'High Priority',
});
FixMyStreet::DB->resultset("ContactResponsePriority")->create({
    contact => $contact,
    response_priority => $rp,
});

my ($report) = $mech->create_problems_for_body(1, $oxon->id, 'Test', {
    category => 'Cows', cobrand => 'fixmystreet', areas => ',2237,' });
my $report_id = $report->id;

my $user = $mech->log_in_ok('test@example.com');
$user->update( { from_body => $oxon } );

FixMyStreet::override_config {
    MAPIT_URL => 'http://mapit.mysociety.org/',
    ALLOWED_COBRANDS => 'fixmystreet',
}, sub {
    subtest "test inspect page" => sub {
        $mech->get_ok("/report/$report_id");
        $mech->content_lacks('Inspect');
        $mech->content_lacks('Manage');

        $user->user_body_permissions->create({ body => $oxon, permission_type => 'report_edit_priority' });
        $mech->get_ok("/report/$report_id");
        $mech->content_contains('Manage');
        $mech->follow_link_ok({ text => 'Manage' });

        $user->user_body_permissions->create({ body => $oxon, permission_type => 'report_inspect' });
        $mech->get_ok("/report/$report_id");
        $mech->content_contains('Inspect');
        $mech->follow_link_ok({ text => 'Inspect' });
    };

    subtest "test basic inspect submission" => sub {
        $mech->submit_form_ok({ button => 'save', with_fields => { traffic_information => 'Lots', state => 'Planned' } });
        $report->discard_changes;
        is $report->state, 'planned', 'report state changed';
        is $report->get_extra_metadata('traffic_information'), 'Lots', 'report data changed';
    };

    subtest "test location changes" => sub {
        $mech->get_ok("/report/$report_id/inspect");
        $mech->submit_form_ok({ button => 'save', with_fields => { latitude => 55, longitude => -2 } });
        $mech->content_contains('Invalid location');
        $mech->submit_form_ok({ button => 'save', with_fields => { latitude => 51.754926, longitude => -1.256179 } });
        $mech->content_lacks('Invalid location');
    };

    foreach my $test (
        { type => 'report_edit_priority', priority => 1 },
        { type => 'report_edit_category', category => 1 },
        { type => 'report_inspect', priority => 1, category => 1, detailed => 1 },
    ) {
        subtest "test $test->{type} permission" => sub {
            $user->user_body_permissions->delete;
            $user->user_body_permissions->create({ body => $oxon, permission_type => $test->{type} });
            $mech->get_ok("/report/$report_id/inspect");
            has_or_lacks($test->{priority}, 'Priority');
            has_or_lacks($test->{priority}, 'High');
            has_or_lacks($test->{category}, 'Category');
            has_or_lacks($test->{detailed}, 'Detailed problem information');
            $mech->submit_form_ok({
                button => 'save',
                with_fields => {
                    $test->{priority} ? (priority => 1) : (),
                    $test->{category} ? (category => 'Cows') : (),
                    $test->{detailed} ? (detailed_information => 'Highland ones') : (),
                }
            });
        };
    }
};

END {
    $mech->delete_body($oxon);
    $mech->delete_body($brum);
    done_testing();
}

sub has_or_lacks {
    my ($flag, $text) = @_;
    $flag ? $mech->content_contains($text) : $mech->content_lacks($text);
}
