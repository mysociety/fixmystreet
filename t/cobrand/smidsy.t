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
        my $liverpool = $c->model("DB::Body")->find_or_create({
            id => 2527,
            name => 'Liverpool City Council',
        });
        $liverpool->body_areas->create({
            area_id => 2527,
        });

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
        my $uri = $mech->uri;
        ok ($mech->uri =~ m{/report/(\d+)$}, "Report posted and returned an ID $uri") or do {
            die;
            return; # abort if fail
        };
        my $id = $1;

        ok (my $report = $c->model('DB::Problem')->find($id), 
            "Retrieved report $id from DB") or return;
        is $report->category, 'vehicle-serious', 'category set correctly in DB';

        # check that display is ok
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
        $mech->content_contains('Thanks for your feedback.  We\'ll get back to you as soon as we can!');
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
