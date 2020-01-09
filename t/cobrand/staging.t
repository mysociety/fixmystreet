use FixMyStreet::TestMech;
my $mech = FixMyStreet::TestMech->new;

subtest 'staging banner is visible by default on staging sites' => sub {
    $mech->get_ok('/');
    $mech->content_contains('<div class="dev-site-notice">');
};

FixMyStreet::override_config {
    STAGING_FLAGS => { hide_staging_banner => 1 },
}, sub {
    subtest 'staging banner can be hidden through STAGING_FLAGS config' => sub {
        $mech->get_ok('/');
        $mech->content_lacks('<div class="dev-site-notice">');
    };
};

done_testing();
