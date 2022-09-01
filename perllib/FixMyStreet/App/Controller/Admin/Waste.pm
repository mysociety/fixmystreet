package FixMyStreet::App::Controller::Admin::Waste;

use JSON::MaybeXS;
use Moose;
use Try::Tiny;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

FixMyStreet::App::Controller::Admin::Waste - Catalyst Controller

=head1 DESCRIPTION

Admin pages for configuring WasteWorks parameters

=head1 METHODS

=cut

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;

    my $user = $c->user;

    if ($user->is_superuser) {
        $c->forward('fetch_wasteworks_bodies');
    } elsif ( $user->from_body ) {
        $c->forward('load_wasteworks_body', [ $user->from_body->id ]);
        $c->res->redirect( $c->uri_for_action( 'admin/waste/edit', $c->stash->{body}->id ) );
    } else {
        $c->detach( '/page_error_404_not_found', [] );
    }
}

sub edit : Path : Args(1) {
    my ( $self, $c, $body_id ) = @_;

    foreach (qw(status_message)) {
        $c->stash->{$_} = $c->flash->{$_} if $c->flash->{$_};
    }

    $c->forward('load_wasteworks_body', [ $body_id ]);
    $c->forward('stash_body_config_json');
    $c->forward('/auth/get_csrf_token');

    if ($c->req->method eq 'POST') {
        $c->forward('/auth/check_csrf_token');

        my $new_cfg;
        try {
            $new_cfg = JSON->new->utf8(1)->allow_nonref(0)->decode($c->get_param("body_config"));
        } catch {
            $c->stash->{errors} ||= {};
            my $e = $_;
            $e =~ s/ at \/.*$//; # trim the filename/lineno
            $c->stash->{errors}->{body_config} = sprintf(_("Not a valid JSON string: %s"), $e);
            $c->detach;
        };
        if (ref $new_cfg ne 'HASH') {
            $c->stash->{errors} ||= {};
            $c->stash->{errors}->{body_config} = _("Config must be a JSON object literal, not array.");
            $c->detach;
        }
        $c->stash->{body}->set_extra_metadata("wasteworks_config", $new_cfg);
        $c->stash->{body}->update;
        $c->flash->{status_message} = _("Updated!");
        $c->res->redirect( $c->uri_for_action( '/admin/waste/edit', $c->stash->{body}->id ) );
    }
}

sub fetch_wasteworks_bodies : Private {
    my ( $self, $c ) = @_;

    my @bodies = $c->model('DB::Body')->search(undef, {
        columns => [ "id", "name", "extra" ],
    })->active;

    @bodies = grep {
        $_->get_cobrand_handler &&
        $_->get_cobrand_handler->feature('waste_features') &&
        $_->get_cobrand_handler->feature('waste_features')->{admin_config_enabled}
    } @bodies;
    $c->stash->{bodies} = \@bodies;
}

sub stash_body_config_json : Private {
    my ($self, $c) = @_;

    if ( my $new_cfg = $c->get_param("body_config") ) {
        $c->stash->{body_config_json} = $new_cfg;
    } else {
        my $cfg = $c->stash->{body}->get_extra_metadata("wasteworks_config", {});
        $c->stash->{body_config_json} = JSON->new->utf8(1)->pretty->canonical->encode($cfg);
    }
}

sub load_wasteworks_body : Private {
    my ($self, $c, $body_id) = @_;

    unless ( $c->user->has_body_permission_to('wasteworks_config', $body_id) ) {
        $c->detach( '/page_error_404_not_found', [] );
    }

    # Regular users can only view their own body's config
    if ( !$c->user->is_superuser && $body_id ne $c->user->from_body->id ) {
        $c->res->redirect( $c->uri_for_action( '/admin/waste/edit', $c->user->from_body->id ) );
    }

    $c->stash->{body} = $c->model('DB::Body')->find($body_id)
        or $c->detach( '/page_error_404_not_found', [] );
}


1;
