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

sub body : Chained('/') : PathPart('admin/waste') : CaptureArgs(1) {
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

    foreach (qw(status_message)) {
        $c->stash->{$_} = $c->flash->{$_} if $c->flash->{$_};
    }

    $c->forward('stash_body_config_json');
}


sub edit : Chained('body') : PathPart('') : Args(0) {
    my ( $self, $c ) = @_;

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
            $c->stash->{errors}->{body_config} =
                sprintf(_("Not a valid JSON string: %s"), $e);
            $c->detach;
        };
        if (ref $new_cfg ne 'HASH') {
            $c->stash->{errors} ||= {};
            $c->stash->{errors}->{body_config} =
                _("Config must be a JSON object literal, not array.");
            $c->detach;
        }
        $c->stash->{body}->set_extra_metadata("wasteworks_config", $new_cfg);
        $c->stash->{body}->update;
        $c->flash->{status_message} = _("Updated!");
        $c->res->redirect(
            $c->uri_for_action( '/admin/waste/edit', [ $c->stash->{body}->id ] )
        );
    }
}

sub bulky_items : Chained('body') {
    my ( $self, $c ) = @_;

    $c->forward('/auth/get_csrf_token');

    my $cfg = $c->stash->{body}->get_extra_metadata("wasteworks_config", {});
    $c->stash->{item_list} = $cfg->{item_list} || [];

    my $cobrand = $c->stash->{body}->get_cobrand_handler;
    $c->stash->{available_features} =
        $cobrand->call_hook('bulky_available_feature_types') if $cobrand;

    if ($c->req->method eq 'POST') {
        $c->forward('/auth/check_csrf_token');

        $c->stash->{has_errors} = 0;

        my @indices = grep { /^bartec_id\[\d+\]/ } keys %{ $c->req->params };
        @indices = sort map { /(\d+)/ } @indices;
        my @items;
        foreach my $i (@indices) {
            if (($c->get_param("delete") // "") eq $i) {
                next;
            }
            my $item = {
                bartec_id => $c->get_param("bartec_id[$i]"),
                category => $c->get_param("category[$i]"),
                name => $c->get_param("name[$i]"),
                message => $c->get_param("message[$i]"),
                price => $c->get_param("price[$i]"),
            };

            # validate the row - if any field has a value then need to check
            # that the three required fields are all present
            my $any_value = 0;
            map { $any_value ||= $_ } values %$item;
            if ($any_value) {
                # OK to store errors in $item itself as it won't get persisted,
                # and $i might not be the same when form is re-rendered.
                foreach (qw(name category bartec_id)) {
                    if (!$item->{$_}) {
                        $item->{errors} ||= {};
                        $item->{errors}->{$_} = _("This field is required.");
                        $c->stash->{has_errors} = 1;
                    }
                }
                # this is within the $any_value check as we don't want to push
                # empty items
                push @items, $item;
            }
        }
        unless ($c->stash->{has_errors}) {
            $cfg->{item_list} = \@items;
            $c->stash->{body}->set_extra_metadata("wasteworks_config", $cfg);
            $c->stash->{body}->update;
            $c->flash->{status_message} = _("Updated!");
            $c->res->redirect(
                $c->uri_for_action( '/admin/waste/bulky_items',
                    [ $c->stash->{body}->id ]
                )
            );
        } else {
            $c->stash->{item_list} = \@items;
        }
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

1;
