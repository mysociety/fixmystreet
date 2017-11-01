use FixMyStreet::TestMech;
my $mech = FixMyStreet::TestMech->new;

my $oxon = $mech->create_body_ok(2237, 'Oxfordshire County Council' );
my $contact = $mech->create_contact_ok( body_id => $oxon->id, category => 'Cows', email => 'cows@example.net' );

my ($report) = $mech->create_problems_for_body(1, $oxon->id, 'Test', {
    category => 'Cows', cobrand => 'fixmystreet',
});
my $report_id = $report->id;


foreach my $council (qw/oxfordshire bromley/) {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ $council ],
    }, sub {
        ok $mech->host("$council.fixmystreet.com"), "change host to $council";
        $mech->get_ok('/');
        $mech->content_like( qr/\u$council/ );
    };
}


foreach my $test (
    { cobrand => 'fixmystreet', social => 1 },
    { cobrand => 'bromley', social => 0 },
) {

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ $test->{cobrand} ],
        FACEBOOK_APP_ID => 'facebook-app-id',
        TWITTER_KEY => 'twitter-key',
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $mech->get_ok('/auth');
        $mech->contains_or_lacks($test->{social}, "Log in with Facebook");
        $mech->contains_or_lacks($test->{social}, "Log in with Twitter");

        $mech->get_ok("/report/new?lat=51.754926&lon=-1.256179");
        $mech->contains_or_lacks($test->{social}, "Log in with Facebook");
        $mech->contains_or_lacks($test->{social}, "Log in with Twitter");

        $mech->get_ok("/report/$report_id");
        $mech->contains_or_lacks($test->{social}, "Log in with Facebook");
        $mech->contains_or_lacks($test->{social}, "Log in with Twitter");
    };
};


done_testing();
