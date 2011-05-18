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

    $c->forward( 'setup_page' );
    $c->forward( 'validate' ) || $c->forward( '/report/display', [ $c->req->param( 'id' ) ] );

    # just go back to the report page for now
    $c->go( '/report/display', [ $c->req->param( 'id' ) ] );
    return 1;
}

sub setup_page : Private {
    my ( $self, $c ) = @_;

    $c->stash->{problem} = $c->model( 'DB::Problem' )->find(
        { id => $c->req->param('id') }
    );
}

sub validate : Private {
    my ( $self, $c ) = @_;

    my %field_errors = ();

    if ( $c->req->param( 'update' ) !~ /\S/ ) {
        $field_errors{update} = _('Please enter a message');
    }

   if ($c->req->param('rznvy') !~ /\S/) {
       $field_errors{email} = _('Please enter your email');
   } elsif (!mySociety::EmailUtil::is_valid_email($c->req->param('rznvy'))) {
       $field_errors{email} = _('Please enter a valid email');
   }

    if ( scalar keys %field_errors ) {
        $c->stash->{field_errors} = \%field_errors;
        return;
    }

    return 1;
}


__PACKAGE__->meta->make_immutable;

1;
