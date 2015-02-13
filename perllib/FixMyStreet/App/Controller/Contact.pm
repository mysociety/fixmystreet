package FixMyStreet::App::Controller::Contact;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

use mySociety::EmailUtil;

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

    $c->res->redirect( '/contact' ) and return unless $c->req->method eq 'POST';

    return
      unless $c->forward('setup_request')
          && $c->forward('determine_contact_type')
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

    my $id = $c->req->param('id');
    my $update_id = $c->req->param('update_id');
    my $token = $c->req->param('m');
    $id        = undef unless $id        && $id        =~ /^[1-9]\d*$/;
    $update_id = undef unless $update_id && $update_id =~ /^[1-9]\d*$/;

    if ($token) {
        my $token_obj = $c->forward('/tokens/load_auth_token', [ $token, 'moderation' ]);
        my $problem = $c->cobrand->problems->find( { id => $token_obj->data->{id} } );
        if ($problem) {
            $c->stash->{problem} = $problem;
            $c->stash->{moderation_complaint} = $token;
        } else {
            $c->forward( '/report/load_problem_or_display_error', [ $id ] );
        }

    } elsif ($id) {
        $c->forward( '/report/load_problem_or_display_error', [ $id ] );
        if ($update_id) {
            my $update = $c->model('DB::Comment')->find(
                { id => $update_id }
            );

            $c->stash->{update} = $update;
        }
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
        name    => _('Please enter your name'),
        em      => _('Please enter your email'),
        subject => _('Please enter a subject'),
        message => _('Please write a message')
    );

    foreach my $field ( keys %required ) {
        $field_errors{$field} = $required{$field}
          unless $c->req->param($field) =~ /\S/;
    }

    unless ( $field_errors{em} ) {
        $field_errors{em} = _('Please enter a valid email address')
          if !mySociety::EmailUtil::is_valid_email( $c->req->param('em') );
    }

    %field_errors = (
        %field_errors,
        $c->cobrand->extra_contact_validation($c)
    );

    push @errors, _('Illegal ID')
      if $c->req->param('id') && !$c->stash->{problem}
          or $c->req->param('update_id') && !$c->stash->{update};

    push @errors, _('There was a problem showing this page. Please try again later.')
      if $c->req->params->{message} && $c->req->params->{message} =~ /\[url=|<a/;

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

    my $base_url = $c->cobrand->base_url();
    my $admin_url = $c->cobrand->admin_base_url;

    if ( $c->stash->{update} ) {

        my $problem_url = $base_url . '/report/' . $c->stash->{update}->problem_id
            . '#update_' . $c->stash->{update}->id;
        my $admin_url = " - $admin_url" . '/update_edit/' . $c->stash->{update}->id
            if $admin_url;
        $c->stash->{message} .= sprintf(
            " \n\n[ Complaint about update %d on report %d - %s%s ]",
            $c->stash->{update}->id,
            $c->stash->{update}->problem_id,
            $problem_url, $admin_url
        );
    }
    elsif ( $c->stash->{problem} ) {

        my $problem_url = $base_url . '/report/' . $c->stash->{problem}->id;
        $admin_url = " - $admin_url" . '/report_edit/' . $c->stash->{problem}->id
            if $admin_url;
        $c->stash->{message} .= sprintf(
            " \n\n[ Complaint about report %d - %s%s ]",
            $c->stash->{problem}->id,
            $problem_url, $admin_url
        );

        # flag this so it's automatically listed in the admin interface
        $c->stash->{problem}->flagged(1);
        $c->stash->{problem}->update;
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

    my $recipient      = $c->cobrand->contact_email;
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
