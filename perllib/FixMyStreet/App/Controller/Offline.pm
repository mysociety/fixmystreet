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

Offline pages Catalyst Controller - service worker and appcache.

=head1 METHODS

=cut

sub service_worker : Path("/service-worker.js") {
    my ($self, $c) = @_;
    $c->res->content_type('application/javascript');
}

sub fallback : Local {
    my ($self, $c) = @_;
}

sub manifest: Path("/.well-known/manifest.webmanifest") {
    my ($self, $c) = @_;
    $c->res->content_type('application/manifest+json');

    my $theme = $c->model('DB::ManifestTheme')->find({ cobrand => $c->cobrand->moniker });
    unless ( $theme ) {
        $theme = $c->model('DB::ManifestTheme')->new({
            name => $c->stash->{site_name},
            short_name => $c->stash->{site_name},
            background_colour => '#ffffff',
            theme_colour => '#ffd000',
        });
    }

    my @icons;
    my $uri = '/theme/' . $c->cobrand->moniker;
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

    unless (@icons) {
        push @icons,
            { src => "/cobrands/fixmystreet/images/192.png", sizes => "192x192", type => "image/png" },
            { src => "/cobrands/fixmystreet/images/512.png", sizes => "512x512", type => "image/png" };
    }

    my $data = {
        name => $theme->name,
        short_name => $theme->short_name,
        background_color => $theme->background_colour,
        theme_color => $theme->theme_colour,
        icons => \@icons,
        lang => $c->stash->{lang_code},
        display => "minimal-ui",
        start_url => "/?pwa",
        scope => "/",
    };
    if ($c->cobrand->can('manifest')) {
        $data = { %$data, %{$c->cobrand->manifest} };
    }

    my $json = encode_json($data);
    $c->res->body($json);
}

# Old appcache functions below

sub have_appcache : Private {
    my ($self, $c) = @_;
    return $c->user_exists && $c->user->has_body_permission_to('planned_reports')
        && !($c->user->is_superuser && FixMyStreet->staging_flag('enable_appcache', 0));
}

sub appcache_manifest : Path("/offline/appcache.manifest") {
    my ($self, $c) = @_;
    unless ($c->forward('have_appcache')) {
        $c->response->status(404);
        $c->response->body('NOT FOUND');
    }
    $c->res->content_type('text/cache-manifest; charset=utf-8');
    $c->res->header(Cache_Control => 'no-cache, no-store');
}

sub appcache : Path("/offline/appcache") {
    my ($self, $c) = @_;
    $c->detach('/page_error_404_not_found', []) if keys %{$c->req->params} && !$c->req->query_keywords;
    unless ($c->forward('have_appcache')) {
        $c->response->status(404);
        $c->response->body('NOT FOUND');
    }
}

__PACKAGE__->meta->make_immutable;

1;
