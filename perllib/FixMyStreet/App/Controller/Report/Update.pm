package FixMyStreet::App::Controller::Report::Update;

use Moose;
use namespace::autoclean;
BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

FixMyStreet::App::Controller::Report::Update

=head1 DESCRIPTION

Creates an update to a report

=cut

sub report_update : Path : Args(0) {
    my ( $self, $c ) = @_;

#    my $q = shift;
#    my @vars = qw(id name rznvy update fixed upload_fileid add_alert);
#    my %input = map { $_ => $q->param($_) || '' } @vars;
#    my @errors;
#    my %field_errors;
#
#    my $fh = $q->upload('photo');
#    if ($fh) {
#        my $err = Page::check_photo($q, $fh);
#        push @errors, $err if $err;
#    }
#
#    my $image;
#    if ($fh) {
#        try {
#            $image = Page::process_photo($fh);
#        } catch Error::Simple with {
#            my $e = shift;
#            push(@errors, sprintf(_("That image doesn't appear to have uploaded correctly (%s), please try again."), $e));
#        };
#    }
#
#    if ($input{upload_fileid}) {
#        open FP, mySociety::Config::get('UPLOAD_CACHE') . $input{upload_fileid};
#        $image = join('', <FP>);
#        close FP;
#    }
#
#    return display_problem($q, \@errors, \%field_errors) if (@errors || scalar(keys(%field_errors)));
#    my $cobrand = Page::get_cobrand($q);
#    my $cobrand_data = Cobrand::extra_update_data($cobrand, $q);
#    my $id = dbh()->selectrow_array("select nextval('comment_id_seq');");
#    Utils::workaround_pg_bytea("insert into comment
#        (id, problem_id, name, email, website, text, state, mark_fixed, photo, lang, cobrand, cobrand_data)
#        values (?, ?, ?, ?, '', ?, 'unconfirmed', ?, ?, ?, ?, ?)", 7,
#        $id, $input{id}, $input{name}, $input{rznvy}, $input{update},
#        $input{fixed} ? 't' : 'f', $image, $mySociety::Locale::lang, $cobrand, $cobrand_data);
#
#    my %h = ();
#    $h{update} = $input{update};
#    $h{name} = $input{name} ? $input{name} : _("Anonymous");
#    my $base = Page::base_url_with_lang($q, undef, 1);
#    $h{url} = $base . '/C/' . mySociety::AuthToken::store('update', { id => $id, add_alert => $input{add_alert} } );
#    dbh()->commit();
#
#    my $out = Page::send_confirmation_email($q, $input{rznvy}, $input{name}, 'update', %h);
#    return $out;

         $c->forward('setup_page')
      && $c->forward('process_user')
      && $c->forward('process_update')
      && $c->forward('check_for_errors')
      or $c->go( '/report/display', [ $c->req->param('id') ] );

    $c->forward('save_update');

    # just go back to the report page for now
    $c->go( '/report/display', [ $c->req->param('id') ] );
    return 1;
}

sub setup_page : Private {
    my ( $self, $c ) = @_;

    my $problem =
      $c->model('DB::Problem')->find( { id => $c->req->param('id') } );

    return unless $problem;

    $c->stash->{problem} = $problem;

    return 1;
}

=head2 process_user

Load user from the database or prepare a new one.

=cut

sub process_user : Private {
    my ( $self, $c ) = @_;

    # FIXME - If user already logged in use them regardless

    # Extract all the params to a hash to make them easier to work with
    my %params =    #
      map { $_ => scalar $c->req->param($_) }    #
      ( 'rznvy', 'name' );

    # cleanup the email address
    my $email = $params{rznvy} ? lc $params{rznvy} : '';
    $email =~ s{\s+}{}g;

    my $update_user = $c->model('DB::User')->find_or_new( { email => $email } );

    # set the user's name if they don't have one
    $update_user->name( _trim_text( $params{name} ) )
      unless $update_user->name;

    $c->stash->{update_user} = $update_user;

    return 1;
}

sub process_update : Private {
    my ( $self, $c ) = @_;

    my %params =    #
      map { $_ => scalar $c->req->param($_) } ( 'update', 'name' );

    my $update = $c->model('DB::Comment')->new(
        {
            text    => $params{update},
            name    => _trim_text( $params{name} ),
            problem => $c->stash->{problem},
            user    => $c->stash->{update_user}
        }
    );

    $c->stash->{update} = $update;

    return 1;
}

sub _trim_text {
    my $input = shift;
    for ($input) {
        last unless $_;
        s{\s+}{ }g;    # all whitespace to single space
        s{^ }{};       # trim leading
        s{ $}{};       # trim trailing
    }
    return $input;
}

=head2 check_for_errors

Examine the user and the report for errors. If found put them on stash and
return false.

=cut

sub check_for_errors : Private {
    my ( $self, $c ) = @_;

    # let the model check for errors
    my %field_errors = (
        %{ $c->stash->{update_user}->check_for_errors },
        %{ $c->stash->{update}->check_for_errors },
    );

    $c->log->debug( join ', ', keys %field_errors );

    # all good if no errors
    return 1 unless scalar keys %field_errors;

    $c->stash->{field_errors} = \%field_errors;

    return;
}

sub save_update : Private {
    my ( $self, $c ) = @_;

    if ( $c->stash->{update_user}->in_storage ) {
        $c->stash->{update_user}->update_user;
    } else {
        $c->stash->{update_user}->insert;
    }

    if ( $c->stash->{update}->in_storage ) {
        $c->stash->{update}->update;
    } else {
        $c->stash->{update}->insert;
    }
}

__PACKAGE__->meta->make_immutable;

1;
