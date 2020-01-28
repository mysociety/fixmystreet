use FixMyStreet::TestMech;
use FixMyStreet::DB;
use Path::Tiny;

my $mech = FixMyStreet::TestMech->new;

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'test'
}, sub {
    my $theme_dir = path(FixMyStreet->path_to('web/theme/test'));
    $theme_dir->mkpath;
    my $image_path = path('t/app/controller/sample.jpg');
    $image_path->copy($theme_dir->child('sample.jpg'));
    subtest 'manifest' => sub {
        my $j = $mech->get_ok_json('/.well-known/manifest.webmanifest');
        is $j->{name}, 'FixMyStreet', 'correct name';
        is $j->{theme_color}, '#ffd000', 'correct theme colour';
        is_deeply $j->{icons}[0], {
            type => 'image/jpeg',
            src => '/theme/test/sample.jpg',
            sizes => '133x100'
        }, 'correct icon';
    };
    subtest 'themed manifest' => sub {
        FixMyStreet::DB->resultset('ManifestTheme')->create({
            cobrand => "test",
            name => "My Test Cobrand FMS",
            short_name => "Test FMS",
            background_colour => "#ff00ff",
            theme_colour => "#ffffff",
        });

        my $j = $mech->get_ok_json('/.well-known/manifest.webmanifest');
        is $j->{name}, 'My Test Cobrand FMS', 'correctly overridden name';
        is $j->{short_name}, 'Test FMS', 'correctly overridden short_name';
        is $j->{background_color}, '#ff00ff', 'correctly overridden background colour';
        is $j->{theme_color}, '#ffffff', 'correctly overridden theme colour';
    };
    $theme_dir->remove_tree;
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'fixmystreet'
}, sub {
    subtest '.com manifest' => sub {
        my $j = $mech->get_ok_json('/.well-known/manifest.webmanifest');
        is $j->{related_applications}[0]{platform}, 'play', 'correct app';
        is $j->{icons}[0]{sizes}, '192x192', 'correct fallback size';
    };
};

subtest 'service worker' => sub {
    $mech->get_ok('/service-worker.js');
    $mech->content_contains('translation_strings');
    $mech->content_contains('offline/fallback');
};

subtest 'offline fallback page' => sub {
    $mech->get_ok('/offline/fallback');
    $mech->content_contains('Offline');
    $mech->content_contains('offline_list');
};

done_testing();