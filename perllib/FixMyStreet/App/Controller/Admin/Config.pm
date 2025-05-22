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

use JSON::MaybeXS;
use Try::Tiny;

=head2 index

This admin page displays the overall configuration for the site.

=cut

sub index : Path( '' ) : Args(0) {
    my ($self, $c) = @_;

    $c->forward('git_version');
    $c->forward('/auth/get_csrf_token');

    my @db_config = FixMyStreet::DB->resultset("Config")->order_by('key')->all;
    my $json = JSON->new->utf8->pretty->canonical->allow_nonref;

    if ($c->req->method eq 'POST') {
        $c->forward('/auth/check_csrf_token');
        $c->stash->{errors} ||= {};

        my $db = FixMyStreet::DB->schema->storage;
        my $txn_guard = $db->txn_scope_guard;

        foreach my $entry (@db_config) {
            if (my $cfg = $c->get_param("db-config-" . $entry->key)) {
                try {
                    $entry->update({ value => $json->decode($cfg) });
                } catch {
                    my $e = $_;
                    $e =~ s/ at \/.*$//; # trim the filename/lineno
                    $c->stash->{errors}->{$entry->key} =
                        sprintf(_("Not a valid JSON string: %s"), $e);
                };
            }
        }

        if (!%{$c->stash->{errors}}) {
            $txn_guard->commit;
            $c->stash->{db_status_message} = _("Updated!");
        }
    }

    foreach (@db_config) {
        if (my $new_cfg = $c->get_param("db-config-" . $_->key)) {
            $_->{json} = $new_cfg;
        } else {
            $_->{json} = $json->encode($_->value);
        }
    }
    $c->stash(
        db_config => \@db_config,
    );
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
