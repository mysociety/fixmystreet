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


$mech->create_contact_ok(body_id => $oxon->id, category => 'Potholes', email => 'potholes@example.org');
my $user = $mech->create_user_ok('customerservices@example.org', name => 'customer services', from_body => $oxon);
$user->user_body_permissions->find_or_create({
    body => $oxon,
    permission_type => 'contribute_as_body',
});
$user->user_body_permissions->find_or_create({
    body => $oxon,
    permission_type => 'contribute_as_another_user',
});

foreach my $test (
    {
        msg    => 'name too short',
        pc     => 'OX4 1QW',
        fields => {
            title         => 'Test title',
            detail        => 'Test detail',
            photo1        => '',
            photo2        => '',
            photo3        => '',
            name          => 'DUDE',
            may_show_name => '1',
            email         => '',
            phone         => '',
            category      => 'Potholes',
            password_sign_in => '',
            password_register => '',
            remember_me => undef,
        },
        changes => {},
        errors  => [
            'Please enter your email',
'Please enter your full name, councils need this information – if you do not wish your name to be shown on the site, untick the box below',
        ],
    },
    {
        msg    => 'name is anonymous',
        pc     => 'OX4 1QW',
        fields => {
            title         => 'Test title',
            detail        => 'Test detail',
            photo1        => '',
            photo2        => '',
            photo3        => '',
            name          => 'anonymous',
            may_show_name => '1',
            email         => '',
            phone         => '',
            category      => 'Potholes',
            password_sign_in => '',
            password_register => '',
            remember_me => undef,
        },
        changes => {},
        errors  => [
            'Please enter your email',
'Please enter your full name, councils need this information – if you do not wish your name to be shown on the site, untick the box below',
        ],
    },
    {
        msg    => 'name too short',
        user   => $user->email,
        pc     => 'OX4 1QW',
        fields => {
            title         => 'Test title',
            detail        => 'Test detail',
            photo1        => '',
            photo2        => '',
            photo3        => '',
            name          => 'DUDE',
            may_show_name => undef,
            phone         => '',
            category      => 'Potholes',
            form_as       => 'another_user',
        },
        changes => {},
        errors  => [
"The given name must be at least 5 chars long. If the user wants to remain anonymous, please report as the Council.",
        ],
    },
    {
        msg    => 'name is anonymous',
        user   => $user->email,
        pc     => 'OX4 1QW',
        fields => {
            title         => 'Test title',
            detail        => 'Test detail',
            photo1        => '',
            photo2        => '',
            photo3        => '',
            name          => 'anonymous',
            may_show_name => undef,
            phone         => '',
            category      => 'Potholes',
            form_as       => 'another_user',
        },
        changes => {},
        errors  => [
"The given name must be at least 5 chars long. If the user wants to remain anonymous, please report as the Council.",
        ],
    },
  )
{
    subtest "check form errors where $test->{msg}" => sub {
        $mech->log_out_ok;
        if ( $test->{user} ) {
            $mech->log_in_ok($test->{user});
        }

        $mech->get_ok('/around');

        # submit initial pc form
        FixMyStreet::override_config {
            ALLOWED_COBRANDS => [ { oxfordshire => '.' } ],
            MAPIT_URL => 'http://mapit.uk/',
        }, sub {
            $mech->submit_form_ok( { with_fields => { pc => $test->{pc} } },
                "submit location" );
            is_deeply $mech->page_errors, [], "no errors for pc '$test->{pc}'";

            # click through to the report page
            $mech->follow_link_ok( { text_regex => qr/skip this step/i, },
                "follow 'skip this step' link" );

            # submit the main form
            my $content = $mech->content;
            $content =~ s/[^[:ascii:]]+//g;
            print $content;
            $mech->submit_form_ok( { with_fields => $test->{fields} },
                "submit form" );
        };

        # check that we got the errors expected
        is_deeply [ sort @{$mech->page_errors} ], [ sort @{$test->{errors}} ], "check errors";

        # check that fields have changed as expected
        my $new_values = {
            %{ $test->{fields} },     # values added to form
            %{ $test->{changes} },    # changes we expect
        };
        is_deeply $mech->visible_form_values, $new_values,
          "values correctly changed";
    };
}


END {
    done_testing();
}
