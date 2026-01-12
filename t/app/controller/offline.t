use FixMyStreet::TestMech;
use FixMyStreet::DB;
use Path::Tiny;
use Memcached;

my $mech = FixMyStreet::TestMech->new;

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'test'
}, sub {
    my $theme_dir = path(FixMyStreet->path_to('web/theme/test'));
    $theme_dir->mkpath;
    my $image_path = path('t/app/controller/sample.jpg');
    $image_path->copy($theme_dir->child('sample.jpg'));
    subtest 'manifest' => sub {
        Memcached::delete("manifest_theme:test");
        my $j = $mech->get_ok_json('/.well-known/manifest-fms.webmanifest');
        is $j->{name}, 'FixMyStreet', 'correct name';
        is $j->{theme_color}, '#ffd000', 'correct theme colour';
        is_deeply $j->{icons}[0], {
            type => 'image/jpeg',
            src => '/theme/test/sample.jpg',
            sizes => '133x100'
        }, 'correct icon';
    };

    my $theme = FixMyStreet::DB->resultset('ManifestTheme')->create({
        cobrand => "test",
        name => "My Test Cobrand FMS",
        short_name => "Test FMS",
        background_colour => "#ff00ff",
        theme_colour => "#ffffff",
        wasteworks_name => "My Test Cobrand Waste",
        wasteworks_short_name => "Test Waste",
    });

    for my $test (
        {
            url => '/.well-known/manifest-fms.webmanifest',
            start_url => '/?pwa',
            name => 'My Test Cobrand FMS',
            short_name => 'Test FMS',
        },
        {
            url => '/.well-known/manifest-waste.webmanifest',
            start_url => '/waste?pwa',
            name => 'My Test Cobrand Waste',
            short_name => 'Test Waste',
        },
    ) {
        subtest "checking webmanifest properties for $test->{url}" => sub {
            Memcached::delete("manifest_theme:test");

            my $j = $mech->get_ok_json($test->{url});
            is $j->{name}, $test->{name}, 'correctly overridden name';
            is $j->{short_name}, $test->{short_name}, 'correctly overridden short name';
            is $j->{background_color}, '#ff00ff', 'correctly overridden background colour';
            is $j->{theme_color}, '#ffffff', 'correctly overridden theme colour';
            is $j->{start_url}, $test->{start_url}, 'correct start url';
        };
    }
    $theme_dir->remove_tree;

    subtest "defaults to FMS name is WW name isn't set" => sub {
        Memcached::delete("manifest_theme:test");
        $theme->update({ wasteworks_name => undef, wasteworks_short_name => undef });

        my $j = $mech->get_ok_json('/.well-known/manifest-fms.webmanifest');
        is $j->{name}, 'My Test Cobrand FMS', 'correct name';
        is $j->{short_name}, 'Test FMS', 'correct short name';
        $j = $mech->get_ok_json('/.well-known/manifest-waste.webmanifest');
        is $j->{name}, 'My Test Cobrand FMS', 'correct name';
        is $j->{short_name}, 'Test FMS', 'correct short name';
    };
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'fixmystreet'
}, sub {
    subtest '.com manifest' => sub {
        my $j = $mech->get_ok_json('/.well-known/manifest-fms.webmanifest');
        is $j->{related_applications}[0]{platform}, 'play', 'correct app';
        is $j->{icons}[0]{sizes}, '192x192', 'correct fallback size';
    };
};

subtest 'service worker' => sub {
    $mech->get_ok('/service-worker.js');
    is $mech->res->header('Cache-Control'), 'max-age=0', 'service worker is not cached';
    $mech->content_contains('translation_strings');
    $mech->content_contains('offline/fallback');
};

subtest 'offline fallback page' => sub {
    $mech->get_ok('/offline/fallback');
    $mech->content_contains('currently offline');
    $mech->content_contains('offline_list');
};

subtest 'offline fallback page' => sub {
    $mech->get_ok('/offline/waste_fallback');
    $mech->content_contains('currently offline');
    $mech->content_contains('bin collections');
};

done_testing();
