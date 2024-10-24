use FixMyStreet::TestMech;
use Test::MockModule;
use Path::Class;

use HTML::Selector::Element qw(find);
use Test::WWW::Mechanize::Catalyst;
my $mech = FixMyStreet::TestMech->new;
my $oxon = $mech->create_body_ok(2237, 'Oxfordshire County Council', { can_be_devolved => 1, cobrand => 'oxfordshire' } );

my $contact = $mech->create_contact_ok( body_id => $oxon->id, category => 'Cows', email => 'cows@example.net' );
my $contact2 = $mech->create_contact_ok( body_id => $oxon->id, category => 'Sheep', email => 'SHEEP', send_method => 'Open311' );
my $contact3 = $mech->create_contact_ok( body_id => $oxon->id, category => 'Badgers & Voles', email => 'badgers@example.net' );

my ($report, $report2, $report3) = $mech->create_problems_for_body(3, $oxon->id, 'Test', {
    category => 'Cows', cobrand => 'fixmystreet', areas => ',2237,2421,',
    whensent => \'current_timestamp',
    latitude => 51.754926, longitude => -1.256179,
});
my $report_id = $report->id;
my $report2_id = $report2->id;
my $report3_id = $report3->id;

$mech->create_user_ok('inspector.manager@example.com', name => 'Inspector Manager');
my $mgr = $mech->log_in_ok('inspector.manager@example.com');
my $ian = $mech->create_user_ok('inspector.ian@example.com', name => 'Inspector Ian');
$ian->from_body( $oxon->id );
$ian->user_body_permissions->create({
    body => $oxon,
    permission_type => 'report_inspect',
});
$ian->update;
$mgr->user_body_permissions->create({ body => $oxon, permission_type => 'assign_report_to_user' });
$mgr->user_body_permissions->create({ body => $oxon, permission_type => 'report_inspect' });
$mgr->set_extra_metadata('categories', [ $contact->id ]);
$mgr->update({from_body => $oxon});


FixMyStreet::override_config {
    MAPIT_URL => 'http://mapit.uk/',
    ALLOWED_COBRANDS => 'oxfordshire',
}, sub {
    subtest "test report assignment" => sub {
        $mech->get_ok("/reports");
        $mech->content_contains('Assign to');

        my $root = HTML::TreeBuilder->new_from_content($mech->content());
        ok ($root->find('select#inspector'), 'Inspector assignment dropdown exists');
        ok ($root->find('input.bulk-assign'), 'Inspector assignment checkboxes exist');

        # check report(s) are not assigned to Ian
        my $get_assignees = sub {
            my @span = $root->find('li div.assigned-to span.assignee');
            return map {map { s/ ^ \s+ | \s+ $ //grx } $_->content_list} @span;
        };
        is_deeply([$get_assignees->()], [], 'all reports correctly unassigned');

        $mech->form_name('bulk-assign-form');
        # HTML::Form does not seem to find external form inputs :(
        # So, copy the checkboxes to inside the form, then tick them.
        my $bulk_form = $mech->current_form;
        my @tickboxes = $root->find('input.bulk-assign');
        for my $box (@tickboxes) {
            $bulk_form->push_input('checkbox', {
                name  => $box->attr('name'),
                id    => $box->id,
                value => $box->attr('value'),
            });
        }

        # check that unassigning unassigned problems
        # isn't a problem
        $mech->select('inspector', 'unassigned');
        $mech->tick('bulk-assign-reports', $report_id);
        $mech->tick('bulk-assign-reports', $report2_id);
        $mech->tick('bulk-assign-reports', $report3_id);
        $mech->click;

        # check report(s) are still not assigned
        $root = HTML::TreeBuilder->new_from_content($mech->content());
        my @assigned_to = $get_assignees->();
        for (0..2) {
            is($assigned_to[$_], undef, 'Report ' . ($_ + 1) . ' still unassigned');
        }

        $mech->form_name('bulk-assign-form');
        # HTML::Form does not seem to find external form inputs :(
        # So, copy the checkboxes to inside the form, then tick them.
        $bulk_form = $mech->current_form;
        @tickboxes = $root->find('input.bulk-assign');
        for my $box (@tickboxes) {
            $bulk_form->push_input('checkbox', {
                name  => $box->attr('name'),
                id    => $box->id,
                value => $box->attr('value'),
            });
        }

        # now try assigning the reports to Ian
        $mech->form_name('bulk-assign-form');
        $mech->select('inspector', $ian->id);
        $mech->tick('bulk-assign-reports', $report_id);
        $mech->tick('bulk-assign-reports', $report2_id);
        $mech->tick('bulk-assign-reports', $report3_id);
        $mech->click;

        # check appropriate report(s) are now assigned to Ian
        $root = HTML::TreeBuilder->new_from_content($mech->content());
        @assigned_to = $get_assignees->();
        for (0..2) {
            like($assigned_to[$_], qr/Inspector Ian/, 'Report ' . ($_ + 1) . ' assigned to Ian');
        }

        # unassign reports
        $mech->form_name('bulk-assign-form');
        # HTML::Form does not seem to find external form inputs :(
        # So, copy the checkboxes to inside the form, then tick them.
        $bulk_form = $mech->current_form;
        @tickboxes = $root->find('input.bulk-assign');
        for my $box (@tickboxes) {
            $bulk_form->push_input('checkbox', {
                name  => $box->attr('name'),
                id    => $box->id,
                value => $box->attr('value'),
            });
        }

        $mech->form_name('bulk-assign-form');
        $mech->select('inspector', 'unassigned');
        $mech->tick('bulk-assign-reports', $report_id);
        $mech->tick('bulk-assign-reports', $report2_id);
        $mech->tick('bulk-assign-reports', $report3_id);
        $mech->click;

        # check reports are now unassigned
        $root = HTML::TreeBuilder->new_from_content($mech->content());
        @assigned_to = $get_assignees->();
        for (0..2) {
            is($assigned_to[$_], undef, 'Report ' . ($_ + 1) . ' unassigned from Ian');
        }
    };
};

done_testing;
