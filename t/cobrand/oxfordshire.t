
use Test::MockModule;
use FixMyStreet::Integrations::ExorRDI;

use FixMyStreet::TestMech;
my $mech = FixMyStreet::TestMech->new;

my $oxon = $mech->create_body_ok(2237, 'Oxfordshire County Council');

subtest 'check /around?ajax defaults to open reports only' => sub {
    my $categories = [ 'Bridges', 'Fences', 'Manhole' ];
    my $params = {
        postcode  => 'OX28 4DS',
        cobrand => 'oxfordshire',
        latitude  =>  51.784721,
        longitude => -1.494453,
    };
    my $bbox = ($params->{longitude} - 0.01) . ',' .  ($params->{latitude} - 0.01)
                . ',' . ($params->{longitude} + 0.01) . ',' .  ($params->{latitude} + 0.01);

    # Create one open and one fixed report in each category
    foreach my $category ( @$categories ) {
        foreach my $state ( 'confirmed', 'fixed' ) {
            my %report_params = (
                %$params,
                category => $category,
                state => $state,
            );
            $mech->create_problems_for_body( 1, $oxon->id, 'Around page', \%report_params );
        }
    }

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ { 'oxfordshire' => '.' } ],
    }, sub {
        my $json = $mech->get_ok_json( '/around?ajax=1&status=all&bbox=' . $bbox );
        my $pins = $json->{pins};
        is scalar @$pins, 6, 'correct number of reports created';

        $json = $mech->get_ok_json( '/around?ajax=1&bbox=' . $bbox );
        $pins = $json->{pins};
        is scalar @$pins, 3, 'correct number of reports returned with no filters';

        $json = $mech->get_ok_json( '/around?ajax=1&filter_category=Fences&bbox=' . $bbox );
        $pins = $json->{pins};
        is scalar @$pins, 1, 'only one Fences report by default';
    }
};

my $superuser = $mech->create_user_ok('superuser@example.com', name => 'Super User', is_superuser => 1);
my $inspector = $mech->create_user_ok('inspector@example.com', name => 'Inspector');
$inspector->user_body_permissions->create({ body => $oxon, permission_type => 'report_inspect' });

my @problems = FixMyStreet::DB->resultset('Problem')->search({}, { rows => 3 })->all;

subtest 'Exor RDI download appears on Oxfordshire cobrand admin' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ { 'oxfordshire' => '.' } ],
    }, sub {
        $mech->log_in_ok( $superuser->email );
        $mech->get_ok('/admin');
        $mech->content_contains("Download Exor RDI");
    }
};

subtest "Exor RDI download doesn't appear outside of Oxfordshire cobrand admin" => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ { 'fixmystreet' => '.' } ],
    }, sub {
        $mech->log_in_ok( $superuser->email );
        $mech->get_ok('/admin');
        $mech->content_lacks("Download Exor RDI");
    }
};

subtest 'Exor file looks okay' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'oxfordshire' ],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $mech->log_in_ok( $superuser->email );
        $mech->get_ok('/admin/exordefects');
        $mech->submit_form_ok( { with_fields => {
            start_date => '2017-05-05',
            end_date => '2017-05-05',
            user_id => $inspector->id,
        } }, 'submit download');
        $mech->content_contains("No inspections by that inspector in the selected date range");

        my $dt = FixMyStreet::DB->resultset('DefectType')->create({
            body => $oxon,
            name => 'Footpath',
            description => 'Footpath stuff',
        });
        $dt->set_extra_metadata(activity_code => 'FC');
        $dt->set_extra_metadata(defect_code => 'SFP1');
        $dt->update;
        my $dt2 = FixMyStreet::DB->resultset('DefectType')->create({
            body => $oxon,
            name => 'Accidental sign damage',
            description => 'Accidental sign damage',
        });
        $dt2->set_extra_metadata(activity_code => 'S');
        $dt2->set_extra_metadata(defect_code => 'ACC2');
        $dt2->update;
        my $i = 123;
        foreach my $problem (@problems) {
            $problem->update({ state => 'action scheduled', external_id => $i });
            $problem->update({ defect_type => $dt }) if $i == 123;
            $problem->set_extra_metadata(traffic_information => 'Signs and Cones') if $i == 124;
            $problem->update({ defect_type => $dt2 }) if $i == 124;
            FixMyStreet::DB->resultset('AdminLog')->create({
                admin_user => $inspector->name,
                user => $inspector,
                object_type => 'problem',
                action => 'inspected',
                object_id => $problem->id,
                whenedited => DateTime->new(year => 2017, month => 5, day => 5, hour => 12),
            });
            $i++;
        }
        $mech->submit_form_ok( { with_fields => {
            start_date => '2017-05-05',
            end_date => '2017-05-05',
            user_id => $inspector->id,
        } }, 'submit download');
        (my $rdi = $mech->content) =~ s/\r\n/\n/g;
        $rdi =~ s/(I,[FMS]C?,,)\d+/$1XXX/g; # Remove unique ID figures, unknown order
        is $rdi, <<EOF, "RDI file matches expected";
"1,1.8,1.0.0.0,ENHN,"
"G,1989169,,,XX,170505,1600,D,INS,N,,,,"
"H,FC"
"I,FC,,XXX,"434970E 209683N Nearest postcode: OX28 4DS.",1200,,,,,,,,"TM none","123 XX TM0 ""
"J,SFP1,2,,,434970,209683,,,,,"
"M,resolve,,,/CFC,,"
"P,0,999999"
"G,1989169,,,XX,170505,1600,D,INS,N,,,,"
"H,MC"
"I,MC,,XXX,"434970E 209683N Nearest postcode: OX28 4DS.",1200,,,,,,,,"TM none","125 XX TM0 ""
"J,SFP2,2,,,434970,209683,,,,,"
"M,resolve,,,/CMC,,"
"P,0,999999"
"G,1989169,,,XX,170505,1600,D,INS,N,,,,"
"H,S"
"I,S,,XXX,"434970E 209683N Nearest postcode: OX28 4DS.",1200,,,,,,,,"TM Signs and Cones","124 XX TM1 ""
"J,ACC2,2,,,434970,209683,,,,,"
"M,resolve,,,/CSI,,"
"P,0,999999"
"X,3,3,3,3,0,0,0,3,0,3,0,0,0"
EOF
        foreach my $problem (@problems) {
            $problem->discard_changes;
            is $problem->get_extra_metadata('rdi_processed'), undef, "Problem was not logged as sent in RDI";
        }

    }
};

subtest 'Reports are marked as inspected correctly' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'oxfordshire' ],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        my $date = DateTime->new(year => 2017, month => 5, day => 5, hour => 12);

        my $now = DateTime->now(
            time_zone => FixMyStreet->time_zone || FixMyStreet->local_time_zone
        );
        my $datetime = Test::MockModule->new('DateTime');
        $datetime->mock('now', sub { $now });

        my $params = {
            start_date => $date,
            end_date => $date,
            inspection_date => $date,
            user => $inspector,
            mark_as_processed => 1,
        };
        my $rdi = FixMyStreet::Integrations::ExorRDI->new($params);
        $rdi->construct;

        foreach my $problem (@problems) {
            $problem->discard_changes;
            is $problem->get_extra_metadata('rdi_processed'), $now->strftime( '%Y-%m-%d %H:%M' ), "Problem was logged as sent in RDI";
        }
    };
};

subtest 'can use customer reference to search for reports' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'oxfordshire' ],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        my $problem = $problems[0];
        $problem->set_extra_metadata( customer_reference => 'ENQ12456' );
        $problem->update;

        $mech->log_out_ok;
        $mech->get_ok('/around?pc=ENQ12456');
        is $mech->uri->path, '/report/' . $problem->id, 'redirects to report';
    };
};

END {
    done_testing();
}
