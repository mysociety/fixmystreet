package FixMyStreet::App::Controller::Admin::Config;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

FixMyStreet::App::Controller::Admin::Config - Catalyst Controller

=head1 DESCRIPTION

Admin pages for viewing/editing site configuration

=head1 METHODS

=cut

=head2 index

This admin page displays the overall configuration for the site.

=cut

sub index : Path( '' ) : Args(0) {
    my ($self, $c) = @_;

    $c->forward('git_version');
}

sub git_version : Private {
    my ($self, $c) = @_;
    my $dir = FixMyStreet->path_to();
    my $git_version = `cd $dir && git describe --tags 2>&1`;
    chomp $git_version;
    $c->stash(
        git_version => $git_version,
    );
}

=head2 cobrand

This displays the COBRAND_FEATURES configuration for the site, grouped by
feature, and provides links to the configuration for each cobrand.

=cut

sub cobrand : Path( 'cobrand_features' ) : Args(0) {
    my ($self, $c) = @_;
    $c->detach('/page_error_403_access_denied', []) unless $c->user->is_superuser;
}

=head2 cobrand_one

This displays the COBRAND_FEATURES configuration for a particular cobrand given
in the URL.

=cut

sub cobrand_one : Path( 'cobrand_features' ) : Args(1) {
    my ($self, $c, $cobrand) = @_;

    $c->detach('/page_error_403_access_denied', []) unless $c->user->is_superuser;

    $c->stash->{cob} = $cobrand;
    my $features = FixMyStreet->config('COBRAND_FEATURES');
    return unless $features && ref $features eq 'HASH';

    my $config = $c->stash->{config} = {};
    my $fallback = $c->stash->{fallback} = {};
    foreach my $feature (sort keys %$features) {
        next unless $features->{$feature} && ref $features->{$feature} eq 'HASH';
        if (defined $features->{$feature}{$cobrand}) {
            $config->{$feature} = $features->{$feature}{$cobrand};
        } elsif (defined $features->{$feature}{_fallback}) {
            $fallback->{$feature} = $features->{$feature}{_fallback};
        }
    }
}

__PACKAGE__->meta->make_immutable;

1;
