package FixMyStreet::App::Controller::Contact;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

use mySociety::Random qw(random_bytes);

=head1 NAME

FixMyStreet::App::Controller::Contact - Catalyst Controller

=head1 DESCRIPTION

Contact us page

=head1 METHODS

=cut

=head2 index

Display contact us page

=cut

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;

    return
      unless $c->forward('setup_request')
          && $c->forward('determine_contact_type');
}

=head2 submit

Handle contact us form submission

=cut

sub submit : Path('submit') : Args(0) {
    my ( $self, $c ) = @_;

    return
      unless $c->forward('setup_request')
          && $c->forward('validate')
          && $c->forward('prepare_params_for_email')
          && $c->forward('send_email');
}

=head2 determine_contact_type

Work out if we have got here via a report/update or this is a
generic contact request and set up things accordingly

=cut

sub determine_contact_type : Private {
    my ( $self, $c ) = @_;

    my $id        = $c->req->param('id');
    my $update_id = $c->req->param('update_id');
    $id        = undef unless $id        && $id        =~ /^[1-9]\d*$/;
    $update_id = undef unless $update_id && $update_id =~ /^[1-9]\d*$/;

    if ($id) {
        my $problem = $c->model('DB::Problem')->find(
            { id => $id },
            {
                'select' => [
                    'title', 'detail', 'name',
                    'anonymous',
                    'user_id', 'confirmed',
                ]
            }
        );

        if ($update_id) {

            # FIXME: updates not implemented yet

#             my $u = dbh()->selectrow_hashref(
#            'select comment.text, comment.name, problem.title, extract(epoch from comment.confirmed) as confirmed
#            from comment, problem where comment.id=?
#            and comment.problem_id = problem.id
#            and comment.problem_id=?', {}, $update_id ,$id);
        }
        elsif ($problem) {
            $c->stash->{problem} = $problem;
        }
        $c->stash->{id} = $id;
    }

    return 1;
}

=head2 validate

Validate the form submission parameters. Sets error messages and redirect 
to index page if errors.

=cut

sub validate : Private {
    my ( $self, $c ) = @_;

    my ( %field_errors, @errors );
    my %required = (
        name    => _('Please give your name'),
        em      => _('Please give your email'),
        subject => _('Please give a subject'),
        message => _('Please write a message')
    );

    foreach my $field ( keys %required ) {
        $field_errors{$field} = $required{$field}
          unless $c->req->param($field) =~ /\S/;
    }

    unless ( $field_errors{em} ) {
        $field_errors{em} = _('Please give a valid email address')
          if !mySociety::EmailUtil::is_valid_email( $c->req->param('em') );
    }

    push @errors, _('Illegal ID')
      if $c->req->param('id') && $c->req->param('id') !~ /^[1-9]\d*$/
          or $c->req->param('update_id')
          && $c->req->param('update_id') !~ /^[1-9]\d*$/;

    unshift @errors,
      _('There were problems with your report. Please see below.')
      if scalar keys %field_errors;

    if ( @errors or scalar keys %field_errors ) {
        $c->stash->{errors}       = \@errors;
        $c->stash->{field_errors} = \%field_errors;
        $c->go('index');
    }

    return 1;
}

=head2 prepare_params_for_email

Does neccessary reformating of exiting params and add any additional
information required for emailing ( problem ids, admin page links etc )

=cut

sub prepare_params_for_email : Private {
    my ( $self, $c ) = @_;

    $c->stash->{message} =~ s/\r\n/\n/g;
    $c->stash->{subject} =~ s/\r|\n/ /g;

    my $base_url       = $c->cobrand->base_url_for_emails;
    my $admin_base_url = $c->cobrand->admin_base_url
      || 'https://secure.mysociety.org/admin/bci/';

    if ( $c->stash->{problem} and $c->stash->{update} ) {

        # FIXME - correct url here
        my $problem_url = $base_url;
        my $admin_url   = $admin_base_url;
        $c->stash->{message} .= sprintf(
            " \n\n[ Complaint about update %d on report %d - %s - %s ]",
            $c->stash->{update}->id,
            $c->stash->{problem}->id,
            $problem_url, $admin_url
        );
    }
    elsif ( $c->stash->{problem} ) {

        # FIXME - correct url here
        my $problem_url = $base_url;
        my $admin_url   = $admin_base_url;
        $c->stash->{message} .= sprintf(
            " \n\n[ Complaint about report %d - %s - %s ]",
            $c->stash->{problem}->id,
            $problem_url, $admin_url
        );
    }

    return 1;
}

=head2 setup_request

Pulls things from request into stash and adds other information
generally required to stash

=cut

sub setup_request : Private {
    my ( $self, $c ) = @_;

    $c->stash->{contact_email} = $c->cobrand->contact_email;
    $c->stash->{contact_email} =~ s/\@/&#64;/;

    for my $param (qw/em subject message/) {
        $c->stash->{$param} = $c->req->param($param);
    }

    # name is already used in the stash for the app class name
    $c->stash->{form_name} = $c->req->param('name');

    return 1;
}

=head2 send_email

Sends the email

=cut

sub send_email : Private {
    my ( $self, $c ) = @_;

    my $recipient      = $c->cobrand->contact_email();
    my $recipient_name = $c->cobrand->contact_name();

    $c->stash->{host} = $c->req->header('HOST');
    $c->stash->{ip}   = $c->req->address;
    $c->stash->{ip} .=
      $c->req->header('X-Forwarded-For')
      ? ' ( forwarded from ' . $c->req->header('X-Forwarded-For') . ' )'
      : '';

    $c->send_email( 'contact.txt', {
        to      => [ [ $recipient, _($recipient_name) ] ],
        from    => [ $c->stash->{em}, $c->stash->{form_name} ],
        subject => 'FMS message: ' . $c->stash->{subject},
    });

    # above is always succesful :(
    $c->stash->{success} = 1;

    return 1;
}

=head1 AUTHOR

Struan Donald

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
