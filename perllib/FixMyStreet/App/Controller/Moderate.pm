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
  - user to have a "moderate" record in user_body_permissions (there is
        currently no admin interface for this.  Should be added, but
        while we're trialing this, it's a simple case of adding a DB record
        manually)

The original data of the report is stored in moderation_original_data, so
that it can be reverted/consulted if required.  All moderation events are
stored in moderation_log.  (NB: In future, this could be combined with
admin_log).

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
    $c->detach unless $c->user->has_permission_to(moderate => $problem->bodies_str);

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
        $c->forward('report_moderate_title'),
        $c->forward('report_moderate_detail'),
        $c->forward('report_moderate_anon'),
        $c->forward('report_moderate_photo');

    $c->detach( 'report_moderate_audit', \@types )
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
        admin_user => $user->name,
        object_id => $problem->id,
        object_type => 'problem',
        reason => (sprintf '%s (%s)', $reason, $types_csv),
    });

    my $cobrand = FixMyStreet::Cobrand->get_class_for_moniker($problem->cobrand)->new();

    my $token = $c->model("DB::Token")->create({
        scope => 'moderation',
        data => { id => $problem->id }
    });

    $c->send_email( 'problem-moderated.txt', {

        to      => [ [ $user->email, $user->name ] ],
        types => $types_csv,
        user => $user,
        problem => $problem,
        report_uri => $c->stash->{report_uri},
        report_complain_uri => $c->stash->{cobrand_base} . '/contact?m=' . $token->token,
    });
}

sub report_moderate_hide : Private {
    my ( $self, $c ) = @_;

    my $problem = $c->stash->{problem} or die;

    if ($c->get_param('problem_hide')) {

        $problem->update({ state => 'hidden' });

        $c->res->redirect( '/' ); # Go directly to front-page
        $c->detach( 'report_moderate_audit', ['hide'] ); # break chain here.
    }
}

sub report_moderate_title : Private {
    my ( $self, $c ) = @_;

    my $problem = $c->stash->{problem} or die;
    my $original = $c->stash->{problem_original};

    my $old_title = $problem->title;
    my $original_title = $original->title;

    my $title = $c->get_param('problem_revert_title') ?
        $original_title
        : $self->diff($original_title, $c->get_param('problem_title'));

    if ($title ne $old_title) {
        $original->insert unless $original->in_storage;
        $problem->update({ title => $title });
        return 'title';
    }

    return;
}

sub report_moderate_detail : Private {
    my ( $self, $c ) = @_;

    my $problem = $c->stash->{problem} or die;
    my $original = $c->stash->{problem_original};

    my $old_detail = $problem->detail;
    my $original_detail = $original->detail;
    my $detail = $c->get_param('problem_revert_detail') ?
        $original_detail
        : $self->diff($original_detail, $c->get_param('problem_detail'));

    if ($detail ne $old_detail) {
        $original->insert unless $original->in_storage;
        $problem->update({ detail => $detail });
        return 'detail';
    }
    return;
}

sub report_moderate_anon : Private {
    my ( $self, $c ) = @_;

    my $problem = $c->stash->{problem} or die;
    my $original = $c->stash->{problem_original};

    my $show_user = $c->get_param('problem_show_name') ? 1 : 0;
    my $anonymous = $show_user ? 0 : 1;
    my $old_anonymous = $problem->anonymous ? 1 : 0;

    if ($anonymous != $old_anonymous) {

        $original->insert unless $original->in_storage;
        $problem->update({ anonymous => $anonymous });
        return 'anonymous';
    }
    return;
}

sub report_moderate_photo : Private {
    my ( $self, $c ) = @_;

    my $problem = $c->stash->{problem} or die;
    my $original = $c->stash->{problem_original};

    return unless $original->photo;

    my $show_photo = $c->get_param('problem_show_photo') ? 1 : 0;
    my $old_show_photo = $problem->photo ? 1 : 0;

    if ($show_photo != $old_show_photo) {
        $original->insert unless $original->in_storage;
        $problem->update({ photo => $show_photo ? $original->photo : undef });
        return 'photo';
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
        $c->forward('update_moderate_detail'),
        $c->forward('update_moderate_anon'),
        $c->forward('update_moderate_photo');

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
        admin_user => $user->name,
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
        $comment->update({ state => 'hidden' });
        $c->detach( 'update_moderate_audit', ['hide'] ); # break chain here.
    }
    return;
}

sub update_moderate_detail : Private {
    my ( $self, $c ) = @_;

    my $problem = $c->stash->{problem} or die;
    my $comment = $c->stash->{comment} or die;
    my $original = $c->stash->{comment_original};

    my $old_detail = $comment->text;
    my $original_detail = $original->detail;
    my $detail = $c->get_param('update_revert_detail') ?
        $original_detail
        : $self->diff($original_detail, $c->get_param('update_detail'));

    if ($detail ne $old_detail) {
        $original->insert unless $original->in_storage;
        $comment->update({ text => $detail });
        return 'detail';
    }
    return;
}

sub update_moderate_anon : Private {
    my ( $self, $c ) = @_;

    my $problem = $c->stash->{problem} or die;
    my $comment = $c->stash->{comment} or die;
    my $original = $c->stash->{comment_original};

    my $show_user = $c->get_param('update_show_name') ? 1 : 0;
    my $anonymous = $show_user ? 0 : 1;
    my $old_anonymous = $comment->anonymous ? 1 : 0;

    if ($anonymous != $old_anonymous) {
        $original->insert unless $original->in_storage;
        $comment->update({ anonymous => $anonymous });
        return 'anonymous';
    }
    return;
}

sub update_moderate_photo : Private {
    my ( $self, $c ) = @_;

    my $problem = $c->stash->{problem} or die;
    my $comment = $c->stash->{comment} or die;
    my $original = $c->stash->{comment_original};

    return unless $original->photo;

    my $show_photo = $c->get_param('update_show_photo') ? 1 : 0;
    my $old_show_photo = $comment->photo ? 1 : 0;

    if ($show_photo != $old_show_photo) {
        $original->insert unless $original->in_storage;
        $comment->update({ photo => $show_photo ? $original->photo : undef });
        return 'photo';
    }
}

sub return_text : Private {
    my ($self, $c, $text) = @_;

    $c->res->content_type('text/plain; charset=utf-8');
    $c->res->body( $text // '' );
}

sub diff {
    my ($self, $old, $new) = @_;

    $new =~s/\[\.{3}\]//g;

    my $diff = Algorithm::Diff->new( [ split //, $old ], [ split //, $new ] );
    my $string;
    while ($diff->Next) {
        my $d = $diff->Diff;
        if ($d & 1) {
            my $deleted = join '', $diff->Items(1);
            unless ($deleted =~/^\s*$/) {
                $string .= ' ' if $deleted =~/^ /;
                $string .= '[...]';
                $string .= ' ' if $deleted =~/ $/;
            }
        }
        $string .= join '', $diff->Items(2);
    }
    return $string;
}


__PACKAGE__->meta->make_immutable;

1;
