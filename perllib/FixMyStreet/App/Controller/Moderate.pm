package FixMyStreet::App::Controller::Moderate;

use Moose;
use namespace::autoclean;
use Algorithm::Diff;
BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

FixMyStreet::App::Controller::Moderate - process a moderation event

=head1 DESCRIPTION

The intent of this is that council users will be able to moderate reports
by themselves, but without requiring access to the full admin panel.

From a given report page, an authenticated user will be able to press
the "moderate" button on report and any updates to bring up a form with
data to change.

(Authentication requires:

  - user to be from_body
  - user to have a "moderate" record in user_body_permissions

The original data of the report is stored in moderation_original_data, so
that it can be reverted/consulted if required.  All moderation events are
stored in admin_log.

=head1 SEE ALSO

DB tables:

    AdminLog
    ModerationOriginalData
    UserBodyPermissions

=cut

sub moderate : Chained('/') : PathPart('moderate') : CaptureArgs(0) { }

sub report : Chained('moderate') : PathPart('report') : CaptureArgs(1) {
    my ($self, $c, $id) = @_;
    my $problem = $c->model('DB::Problem')->find($id);

    my $cobrand_base = $c->cobrand->base_url_for_report( $problem );
    my $report_uri = $cobrand_base . $problem->url;
    $c->stash->{cobrand_base} = $cobrand_base;
    $c->stash->{report_uri} = $report_uri;
    $c->res->redirect( $report_uri ); # this will be the final endpoint after all processing...

    # ... and immediately, if the user isn't authorized
    $c->detach unless $c->user_exists;
    $c->detach unless $c->user->can_moderate($problem);

    $c->forward('/auth/check_csrf_token');

    my $original = $problem->find_or_new_related( moderation_original_data => {
        title => $problem->title,
        detail => $problem->detail,
        photo => $problem->photo,
        anonymous => $problem->anonymous,
    });
    $c->stash->{problem} = $problem;
    $c->stash->{problem_original} = $original;
    $c->stash->{moderation_reason} = $c->get_param('moderation_reason') // '';
}

sub moderate_report : Chained('report') : PathPart('') : Args(0) {
    my ($self, $c) = @_;

    $c->forward('report_moderate_hide');

    my @types = grep $_,
        $c->forward('moderate_text', [ 'title' ]),
        $c->forward('moderate_text', [ 'detail' ]),
        $c->forward('moderate_boolean', [ 'anonymous', 'show_name' ]),
        $c->forward('moderate_boolean', [ 'photo' ]);

    $c->detach( 'report_moderate_audit', \@types )
}

sub moderating_user_name {
    my $user = shift;
    return $user->from_body ? $user->from_body->name : _('an administrator');
}

sub report_moderate_audit : Private {
    my ($self, $c, @types) = @_;

    my $user = $c->user->obj;
    my $reason = $c->stash->{'moderation_reason'};
    my $problem = $c->stash->{problem} or die;

    my $types_csv = join ', ' => @types;

    $c->model('DB::AdminLog')->create({
        action => 'moderation',
        user => $user,
        admin_user => moderating_user_name($user),
        object_id => $problem->id,
        object_type => 'problem',
        reason => (sprintf '%s (%s)', $reason, $types_csv),
    });

    if ($problem->user->email_verified && $c->cobrand->send_moderation_notifications) {
        my $token = $c->model("DB::Token")->create({
            scope => 'moderation',
            data => { id => $problem->id }
        });

        $c->send_email( 'problem-moderated.txt', {
            to => [ [ $problem->user->email, $problem->name ] ],
            types => $types_csv,
            user => $problem->user,
            problem => $problem,
            report_uri => $c->stash->{report_uri},
            report_complain_uri => $c->stash->{cobrand_base} . '/contact?m=' . $token->token,
        });
    }
}

sub report_moderate_hide : Private {
    my ( $self, $c ) = @_;

    my $problem = $c->stash->{problem} or die;

    if ($c->get_param('problem_hide')) {

        $problem->update({ state => 'hidden' });
        $problem->get_photoset->delete_cached;

        $c->res->redirect( '/' ); # Go directly to front-page
        $c->detach( 'report_moderate_audit', ['hide'] ); # break chain here.
    }
}

sub moderate_text : Private {
    my ($self, $c, $thing) = @_;

    my ($object, $original, $param);
    my $thing_for_original_table = $thing;
    if (my $comment = $c->stash->{comment}) {
        $object = $comment;
        $original = $c->stash->{comment_original};
        $param = 'update_';
        # Update 'text' field is stored in original table's 'detail' field
        $thing_for_original_table = 'detail' if $thing eq 'text';
    } else {
        $object = $c->stash->{problem};
        $original = $c->stash->{problem_original};
        $param = 'problem_';
    }

    my $old = $object->$thing;
    my $original_thing = $original->$thing_for_original_table;

    my $new = $c->get_param($param . 'revert_' . $thing) ?
        $original_thing
        : $c->get_param($param . $thing);

    if ($new ne $old) {
        $original->insert unless $original->in_storage;
        $object->update({ $thing => $new });
        return $thing_for_original_table;
    }

    return;
}

sub moderate_boolean : Private {
    my ( $self, $c, $thing, $reverse ) = @_;

    my ($object, $original, $param);
    if (my $comment = $c->stash->{comment}) {
        $object = $comment;
        $original = $c->stash->{comment_original};
        $param = 'update_';
    } else {
        $object = $c->stash->{problem};
        $original = $c->stash->{problem_original};
        $param = 'problem_';
    }

    return if $thing eq 'photo' && !$original->photo;

    my $new;
    if ($reverse) {
        $new = $c->get_param($param . $reverse) ? 0 : 1;
    } else {
        $new = $c->get_param($param . $thing) ? 1 : 0;
    }
    my $old = $object->$thing ? 1 : 0;

    if ($new != $old) {
        $original->insert unless $original->in_storage;
        if ($thing eq 'photo') {
            $object->update({ $thing => $new ? $original->photo : undef });
        } else {
            $object->update({ $thing => $new });
        }
        return $thing;
    }
    return;
}

sub update : Chained('report') : PathPart('update') : CaptureArgs(1) {
    my ($self, $c, $id) = @_;
    my $comment = $c->stash->{problem}->comments->find($id);

    my $original = $comment->find_or_new_related( moderation_original_data => {
        detail => $comment->text,
        photo => $comment->photo,
        anonymous => $comment->anonymous,
    });
    $c->stash->{comment} = $comment;
    $c->stash->{comment_original} = $original;
}

sub moderate_update : Chained('update') : PathPart('') : Args(0) {
    my ($self, $c) = @_;

    $c->forward('update_moderate_hide');

    my @types = grep $_,
        $c->forward('moderate_text', [ 'text' ]),
        $c->forward('moderate_boolean', [ 'anonymous', 'show_name' ]),
        $c->forward('moderate_boolean', [ 'photo' ]);

    $c->detach( 'update_moderate_audit', \@types )
}

sub update_moderate_audit : Private {
    my ($self, $c, @types) = @_;

    my $user = $c->user->obj;
    my $reason = $c->stash->{'moderation_reason'};
    my $problem = $c->stash->{problem} or die;
    my $comment = $c->stash->{comment} or die;

    my $types_csv = join ', ' => @types;

    $c->model('DB::AdminLog')->create({
        action => 'moderation',
        user => $user,
        admin_user => moderating_user_name($user),
        object_id => $comment->id,
        object_type => 'update',
        reason => (sprintf '%s (%s)', $reason, $types_csv),
    });
}

sub update_moderate_hide : Private {
    my ( $self, $c ) = @_;

    my $problem = $c->stash->{problem} or die;
    my $comment = $c->stash->{comment} or die;

    if ($c->get_param('update_hide')) {
        $comment->hide;
        $c->detach( 'update_moderate_audit', ['hide'] ); # break chain here.
    }
    return;
}

sub return_text : Private {
    my ($self, $c, $text) = @_;

    $c->res->content_type('text/plain; charset=utf-8');
    $c->res->body( $text // '' );
}

__PACKAGE__->meta->make_immutable;

1;
