use FixMyStreet::TestMech;
my $mech = FixMyStreet::TestMech->new;

my $oxon = $mech->create_body_ok(2237, 'Oxfordshire County Council');

subtest 'check /ajax defaults to open reports only' => sub {
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
        my $json = $mech->get_ok_json( '/ajax?status=all&bbox=' . $bbox );
        my $pins = $json->{pins};
        is scalar @$pins, 6, 'correct number of reports created';

        $json = $mech->get_ok_json( '/ajax?bbox=' . $bbox );
        $pins = $json->{pins};
        is scalar @$pins, 3, 'correct number of reports returned with no filters';

        $json = $mech->get_ok_json( '/ajax?filter_category=Fences&bbox=' . $bbox );
        $pins = $json->{pins};
        is scalar @$pins, 1, 'only one Fences report by default';
    }
};

my $superuser = $mech->create_user_ok('superuser@example.com', name => 'Super User', is_superuser => 1);
my $inspector = $mech->create_user_ok('inspector@example.com', name => 'Inspector');
$inspector->user_body_permissions->create({ body => $oxon, permission_type => 'report_inspect' });

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
            start_date => '05/05/2017',
            end_date => '05/05/2017',
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
        my @problems = FixMyStreet::DB->resultset('Problem')->search({}, { rows => 2 })->all;
        my $i = 123;
        foreach my $problem (@problems) {
            $problem->update({ state => 'action scheduled', external_id => $i });
            $problem->update({ defect_type => $dt }) if $i == 123;
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
            start_date => '05/05/2017',
            end_date => '05/05/2017',
            user_id => $inspector->id,
        } }, 'submit download');
        (my $rdi = $mech->content) =~ s/\r\n/\n/g;
        $rdi =~ s/(I,[FM]C,,)\d+/$1XXX/g; # Remove unique ID figures, unknown order
        is $rdi, <<EOF, "RDI file matches expected";
"1,1.8,1.0.0.0,ENHN,"
"G,1989169,,,XX,170505,1600,D,INS,N,,,,"
"H,FC"
"I,FC,,XXX,"434970E 209683N Nearest postcode: OX28 4DS.",1200,,,,,,,,"TM none","123 ""
"J,SFP1,2,,,434970,209683,,,,,"
"M,resolve,,,/CFC,,"
"P,0,999999"
"G,1989169,,,XX,170505,1600,D,INS,N,,,,"
"H,MC"
"I,MC,,XXX,"434970E 209683N Nearest postcode: OX28 4DS.",1200,,,,,,,,"TM none","124 ""
"J,SFP2,2,,,434970,209683,,,,,"
"M,resolve,,,/CMC,,"
"P,0,999999"
"X,2,2,2,2,0,0,0,2,0,2,0,0,0"
EOF
    }
};

END {
    done_testing();
}
