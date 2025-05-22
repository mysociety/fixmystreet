package FixMyStreet::App::Controller::Offline;

use Image::Size;
use JSON::MaybeXS;
use Moose;
use Path::Tiny;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

FixMyStreet::App::Controller::Offline - Catalyst Controller

=head1 DESCRIPTION

Offline pages Catalyst Controller - service worker handling

=head1 METHODS

=cut

sub service_worker : Path("/service-worker.js") {
    my ($self, $c) = @_;
    if (FixMyStreet->test_mode && FixMyStreet->test_mode eq 'cypress') {
        $c->res->status(404);
        $c->res->body('');
        return;
    }
    $c->res->headers->header('Cache-Control' => 'max-age=0');
    $c->res->content_type('application/javascript');
}

sub fallback : Local {
    my ($self, $c) = @_;

    # Fetch git version
    $c->forward('/admin/config/git_version');

}

sub drafts : Local {
    my ($self, $c) = @_;
}

sub manifest_waste: Path('/.well-known/manifest-waste.webmanifest') {
    my ($self, $c) = @_;

    $c->forward('send_manifest', [ 'ww']);
}

sub manifest_fms: Path('/.well-known/manifest-fms.webmanifest') {
    my ($self, $c) = @_;

    $c->forward('send_manifest', ['fms']);
}

sub send_manifest: Private {
    my ($self, $c, $app) = @_;

    $c->res->content_type('application/manifest+json');

    my $theme = $c->stash->{manifest_theme};

    my $start_url = '/?pwa';
    my $name = $theme->{name};
    my $short_name = $theme->{short_name};

    if ($app eq 'ww') {
        $start_url = '/waste?pwa';
        $name = $theme->{wasteworks_name} if $theme->{wasteworks_name};
        $short_name = $theme->{wasteworks_short_name} if $theme->{wasteworks_short_name};
    }

    my $data = {
        name => $name,
        short_name => $short_name,
        background_color => $theme->{background_colour},
        theme_color => $theme->{theme_colour},
        icons => $theme->{icons},
        lang => $c->stash->{lang_code},
        display => "minimal-ui",
        start_url => $start_url,
        scope => "/",
    };
    if ($c->cobrand->can('manifest')) {
        $data = { %$data, %{$c->cobrand->manifest} };
    }

    my $json = encode_json($data);
    $c->res->body($json);
}


=head2 assetlinks_json

This serves a JSON file which establishes a link between the FMS website
and the Android app. In practical terms this allows the PWA installed from
the Play Store to render without an address bar on the user's device, as well
as allowing links to FMS to be opened in the FMS app (e.g. when tapping a link
in a report confirmation or login email).

For more info:
    https://developer.android.com/training/app-links/verify-android-applinks

=cut

sub assetlinks_json: Path('/.well-known/assetlinks.json') {
    my ($self, $c) = @_;

    my $cfg = $c->cobrand->feature("android_assetlinks");

    unless ($cfg) {
        $c->res->status(404);
        $c->res->body('');
        return;
    }

    my $data = [{
        relation => ["delegate_permission/common.handle_all_urls"],
        target => {
            namespace => "android_app",
            package_name => $cfg->{package},
            sha256_cert_fingerprints => $cfg->{fingerprints}
        }
    }];

    $c->res->content_type('application/json; charset=utf-8');
    my $json = encode_json($data);
    $c->res->body($json);
}


=head2 apple_app_site_association

This serves a JSON file which enables "Universal Links" on the iOS app.
Much like the assetlinks_json above, this allows links to FMS to be opened in
the FMS app (e.g. when tapping a link in a report confirmation or login email).

For more info:
    https://developer.apple.com/documentation/xcode/supporting-associated-domains

=cut

sub apple_app_site_association: Path('/.well-known/apple-app-site-association') {
    my ($self, $c) = @_;

    my $cfg = $c->cobrand->feature("ios_site_association");

    unless ($cfg) {
        $c->res->status(404);
        $c->res->body('');
        return;
    }

    my $data = {
        applinks => {
            apps => [],
            details => [{
                appID => $cfg->{appID},
                paths => ["/", "*"]
            }]
        }
    };

    $c->res->content_type('application/json; charset=utf-8');
    my $json = JSON->new->utf8(1)->pretty->canonical->encode($data);
    $c->res->body($json);
}


sub _stash_manifest_theme : Private {
    my ($self, $c, $cobrand) = @_;

    $c->stash->{manifest_theme} = $c->forward('_find_manifest_theme', [ $cobrand ]);
}

sub _find_manifest_theme : Private {
    my ($self, $c, $cobrand, $ignore_cache_and_defaults) = @_;

    my $key = "manifest_theme:$cobrand";
    # ignore_cache_and_defaults is only used in the admin, so no harm bypassing cache
    my $manifest_theme = $ignore_cache_and_defaults ? undef : Memcached::get($key);

    unless ( $manifest_theme ) {
        my $theme = $c->model('DB::ManifestTheme')->find({ cobrand => $cobrand });
        unless ( $theme ) {
            $theme = $c->model('DB::ManifestTheme')->new({
                name => $c->stash->{site_name},
                short_name => $c->stash->{site_name},
                background_colour => '#ffffff',
                theme_colour => '#ffd000',
            });
        }

        my @icons;
        my $uri = '/theme/' . $cobrand;
        my $theme_path = path(FixMyStreet->path_to('web' . $uri));
        $theme_path->visit(
            sub {
                my ($x, $y, $typ) = Image::Size::imgsize($_->stringify);
                push @icons, {
                    src => join('/', $uri, $_->basename),
                    sizes => join('x', $x, $y),
                    type => $typ eq 'PNG' ? 'image/png' : $typ eq 'GIF' ? 'image/gif' : $typ eq 'JPG' ? 'image/jpeg' : '',
                };
            }
        );

        unless (@icons || $ignore_cache_and_defaults) {
            push @icons,
                { src => "/cobrands/fixmystreet/images/192.png", sizes => "192x192", type => "image/png" },
                { src => "/cobrands/fixmystreet/images/512.png", sizes => "512x512", type => "image/png" };
        }

        $manifest_theme = {
            icons => \@icons,
            background_colour => $theme->background_colour,
            theme_colour => $theme->theme_colour,
            name => $theme->name,
            short_name => $theme->short_name,
            wasteworks_name => $theme->wasteworks_name,
            wasteworks_short_name => $theme->wasteworks_short_name,
        };

        unless ($ignore_cache_and_defaults) {
            Memcached::set($key, $manifest_theme);
        }
    }

    return $manifest_theme;
}

sub _clear_manifest_theme_cache : Private {
    my ($self, $c, $cobrand ) = @_;

    Memcached::delete("manifest_theme:$cobrand");
}

__PACKAGE__->meta->make_immutable;

1;
