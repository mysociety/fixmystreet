package FixMyStreet::App::Controller::Admin::EmergencyMessage;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    # Normal users can only edit message for the current body.
    $c->detach('edit_emergency_message', [$c->user->from_body]) unless $c->user->is_superuser;

    # Superusers can see a list of all bodies with emergency messages.
    my @bodies = $c->model('DB::Body')->active->search(undef, { order_by => [ 'name', 'id' ] });
    $c->stash->{bodies} = \@bodies;
}

sub edit :Local :Args(1) {
    my ( $self, $c, $body_id ) = @_;

    # Only superusers can edit arbitrary bodies
    $c->detach('/page_error_403_access_denied', []) unless $c->user->is_superuser;

    my $body = $c->model('DB::Body')->find($body_id)
        || $c->detach( '/page_error_404_not_found', [] );

    $c->detach('edit_emergency_message', [$body]);
}

sub edit_emergency_message :Private {
    my ( $self, $c, $body ) = @_;

    if ( $c->req->method eq 'POST' ) {
        $c->forward('/auth/check_csrf_token');

        foreach my $type ("", "_waste", "_reporting") {
            foreach my $ooh ("", "_ooh") {
                my $field = "emergency_message$type$ooh";
                my $message = FixMyStreet::Template::sanitize($c->get_param($field), 1);
                $message =~ s/^\s+|\s+$//g;

                if ( $message ) {
                    $body->set_extra_metadata($field => $message);
                } else {
                    $body->unset_extra_metadata($field);
                }
            }
        }

        my $ooh = $c->forward('parse_ooh_form');
        if (@$ooh) {
            $body->set_extra_metadata(ooh_times => $ooh);
        } else {
            $body->unset_extra_metadata('ooh_times');
        }

        $body->update;
        $c->stash->{status_message} = _('Updated!');
    }

    $c->forward('/auth/get_csrf_token');
    foreach my $type ("", "_waste", "_reporting") {
        foreach my $ooh ("", "_ooh") {
            my $field = "emergency_message$type$ooh";
            $c->stash->{$field} = $body->get_extra_metadata($field);
        }
    }

    $c->stash->{body} = $body;
    $c->stash->{template} = 'admin/emergencymessage/edit.html';

    # Check cobrand for body
    my $cobrand = $body->get_cobrand_handler;
    return unless $cobrand;
    $c->stash->{body_cobrand} = $cobrand;

    my $file = "report/new/form_after_heading.html";
    foreach my $dir_templates (@{$cobrand->path_to_web_templates}) {
        if (-e "$dir_templates/$file") {
            # Cannot use render_fragment as it uses current cobrand, and falls back to base
            my $tt = FixMyStreet::Template->new({
                INCLUDE_PATH => [$dir_templates],
            });
            my $var;
            $tt->process($file, {}, \$var);
            $c->stash->{hardcoded_reporting_message} = $var;
            last;
        }
    }

    my $ooh = $cobrand->ooh_times($body);
    $c->stash->{ooh_times} = $ooh->times;
}

sub parse_ooh_form : Private {
    my ($self, $c) = @_;

    my @indices = grep { /^ooh\[\d+\]\.day/ } keys %{ $c->req->params };
    @indices = map { /(\d+)/ } @indices;
    my @days;
    foreach my $i (@indices) {
        my $day = $c->get_param("ooh[$i].day");
        next unless $day;
        if ($day eq 'x') {
            $day = $c->get_param("ooh[$i].special");
            next unless $day;
        }
        push @days, [
            $day,
            int $c->get_param("ooh[$i].start"),
            int $c->get_param("ooh[$i].end"),
        ];
    }
    @days = sort { $a->[0] <=> $b->[0] or $a->[1] <=> $b->[1] } @days;
    return \@days;
}

1;
