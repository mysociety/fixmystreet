use strict;
use warnings;
use Test::More;

# use minimum number of modules to avoid MAP_TYPE being overridden
# too late (XXX cleanup needed)

use FixMyStreet;
use mySociety::MaPit;

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'smidsy' ],
    BASE_URL => 'http://collideosco.pe',
    MAPIT_URL => 'http://mapit.mysociety.org/',
    MAP_TYPE => 'OSM::TonerLite',
}, sub {

    require FixMyStreet::TestMech;
    my $mech = FixMyStreet::TestMech->new;

    my $c = FixMyStreet::App->new();

    # Create a body to report problems too
    my $liverpool = $c->model("DB::Body")->find_or_create({
        id => 2527,
        name => 'Liverpool City Council',
    });
    $liverpool->body_areas->create({
        area_id => 2527,
    });

    ok $mech->host("collideosco.pe"), "change host to collideosco.pe";
    $mech->get_ok('/');
    $mech->content_contains( 'Find road collisions' );

    $mech->log_in_ok('cyclist@example.org');

    $mech->get_ok('/around?latitude=53.387401499999996;longitude=-2.9439968');
    $mech->content_contains( 'Were you involved in an incident here' );

    # the form will already exist (but hidden in JS)

    # Note that the following requires the steps to run translations
    #   cd bin && ./make_po FixMyStreet-Smidsy && cd ..
    #   commonlib/bin/gettext-makemo --quiet FixMyStreet
    $mech->content_contains( 'Reporting an incident', 'Localisation has worked ok' );

    $mech->content_contains( 'Section 170 of the Road Traffic' );

    subtest 'stats19 report filtering' => sub {
        # Create some stats19 reports
        my $i;
        for $i ( 1 .. 5 ) {
            my %report_params = (
                latitude => 53.3874014 + ($i / 1000000),
                longitude=> -2.9439968  + ($i / 1000000),
                name => "Stats19 Import",
                title => "Stats19 Import $i",
                external_body => 'stats19',
            );
            $mech->create_problems_for_body( 1, 2527, 'Around page', \%report_params );
        }

        # They shouldn't be shown by default
        $mech->content_contains( 'Show reports from the Department of Transport' );
        $mech->content_lacks( 'Stats19 Import 1' );

        # Show them
        $mech->get_ok('/around?latitude=53.387401499999996;longitude=-2.9439968&show_stats19=1');

        $mech->content_contains( 'Hide reports from the Department of Transport' );
        $mech->content_contains( 'Stats19 Import 1' );

        # Delete the problems we've created because they cause problems for
        # other cobrands (e.g. Zurich which also uses the external_body field)
        $c->model('DB::Problem')->search({external_body => 'stats19'})->delete();
    };

    subtest 'custom form fields' => sub {
        $mech->content_contains( 'How severe was the incident?' );
        $mech->content_contains( 'When did it happen?' );
        $mech->content_contains( 'Where did it happen?' );
        $mech->content_contains( 'The incident involved a bike and' );
        $mech->content_contains( 'What was the vehicle&#39;s registration number?' );
        $mech->content_contains( 'Did the emergency services attend?' );
        $mech->content_contains( 'Can you describe what happened?' );
    };

    subtest 'post an incident' => sub {
        $mech->submit_form_ok({
            form_number => 1,
            button => 'submit_register',
            with_fields => {
                latitude => 53.387401499999996,
                longitude=> -2.9439968,
                submit_problem => 1,
                name => 'Test Cyclist',
                title => 'DUMMY', # as in hidden field,
                severity => 60, # Serious
                injury_detail => 'Broken shoulder',
                incident_date => '31/12/2014',
                incident_time => '14:50',
                road_type => 'road',
                participants => 'car',
                registration => 'ABC DEF',
                emergency_services => 'yes',
                detail => 'Hit by red car',
                media_url => 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
            },
        });

        ok ($mech->content =~ m{<h1><a href="http://collideosco.pe/report/(\d+)">Serious incident involving a bicycle and a vehicle</a></h1>}, "Report posted and showed confirmation page") or do {
            die;
            return; # abort if fail
        };
        my $id = $1;

        ok (my $report = $c->model('DB::Problem')->find($id),
            "Retrieved report $id from DB") or return;
        is $report->category, 'vehicle-serious', 'category set correctly in DB';

        # check that display is ok
        $mech->get_ok('/report/' . $id);
        $mech->content_contains( '<h1>Serious incident involving a bicycle and a vehicle</h1>' );
        $mech->content_contains( 'Reported by Test Cyclist at' );
        $mech->content_contains( '(incident occurred: 14:50' );
        $mech->content_contains( 'Details about injuries: Broken shoulder');
        $mech->content_contains( 'Serious ( incident involved serious injury or hospitalisation )' );
        $mech->content_contains( 'Media URL' );
        $mech->content_contains( '<iframe width="320" height="195" src="//www.youtube.com/embed/dQw4w9WgXcQ"' );
        $mech->content_contains( '<img border="0" class="pin" src="http://collideosco.pe/cobrands/smidsy/images/pin-vehicle-serious.png"' );
        $mech->content_contains( q{'map_type': OpenLayers.Layer.Stamen,} )
            or diag $mech->content;
    };

    subtest 'Sponsor contact form' => sub {
        $mech->get_ok('/sponsors');
        $mech->content_contains('This could be you!');

        $mech->submit_form_ok({
            with_fields => {
                company => 'Acme Corp',
                name => 'Wile E Coyote',
                tel => '01234 567 890',
                em => 'wile@example.org',
            },
        });
        $mech->content_contains('Thank you for your feedback');
        ok(my $email = $mech->get_email) or return;

        like $email->body, qr/Company: Acme Corp/, 'Company info sent';
        like $email->body, qr/Tel: 01234 567 890/, 'Tel sent';
        my $from = $email->header('from');
        is $from, '"Wile E Coyote" <wile@example.org>', 'Name/email sent correctly';
        is $email->header('subject'), 'Collideoscope message: Contact from a potential sponsor',
            'Subject correct';
    };

};

done_testing();
