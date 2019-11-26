package FixMyStreet::App::Controller::Contact;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

use MIME::Base64;
use mySociety::EmailUtil;
use FixMyStreet::Email;
use FixMyStreet::Template::SafeString;

=head1 NAME

FixMyStreet::App::Controller::Contact - Catalyst Controller

=head1 DESCRIPTION

Contact us page

=head1 METHODS

=head2 auto

Functions to run on both GET and POST contact requests.

=cut

sub auto : Private {
    my ($self, $c) = @_;
    $c->forward('/auth/get_csrf_token');
}

sub begin : Private {
    my ($self, $c) = @_;
    $c->forward('/begin');
    $c->forward('setup_request');
}

=head2 index

Display contact us page

=cut

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;
    $c->forward('determine_contact_type');
}

=head2 submit

Handle contact us form submission

=cut

sub submit : Path('submit') : Args(0) {
    my ( $self, $c ) = @_;

    $c->forward('determine_contact_type');
    $c->res->redirect( '/contact' ) and return unless $c->req->method eq 'POST';

    $c->go('index') unless $c->forward('validate');
    $c->forward('prepare_params_for_email');
    $c->forward('send_email');
    $c->forward('redirect_on_success');
}

=head2 determine_contact_type

Work out if we have got here via a report/update or this is a
generic contact request and set up things accordingly

=cut

sub determine_contact_type : Private {
    my ( $self, $c ) = @_;

    my $id = $c->get_param('id');
    my $update_id = $c->get_param('update_id');
    my $token = $c->get_param('m');
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
            my $update = $c->cobrand->updates->search(
                {
                    "me.id" => $update_id,
                    problem_id => $id,
                    "me.state" => 'confirmed',
                }
            )->first;

            unless ($update) {
                $c->detach( '/page_error_404_not_found', [ _('Unknown update ID') ] );
            }

            $c->stash->{update} = $update;
        }

        if ( $c->get_param("reject") && $c->user->has_permission_to(report_reject => $c->stash->{problem}->bodies_str_ids) ) {
            $c->stash->{rejecting_report} = 1;
        }
    } elsif ( $c->cobrand->abuse_reports_only ) {
        # General enquiries replaces contact form if enabled
        if ( $c->cobrand->can('setup_general_enquiries_stash') ) {
            $c->res->redirect( '/contact/enquiry' );
            $c->detach;
            return 1;
        } else {
            $c->detach( '/page_error_404_not_found' );
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

    $c->forward('/auth/check_csrf_token');
    my $s = $c->stash->{s} = unpack("N", decode_base64($c->get_param('s')));
    return if !FixMyStreet->test_mode && time() < $s; # uncoverable statement

    my ( %field_errors, @errors );
    my %required = (
        name    => _('Please enter your name'),
        em      => _('Please enter your email'),
        subject => _('Please enter a subject'),
        message => _('Please write a message')
    );

    foreach my $field ( keys %required ) {
        $field_errors{$field} = $required{$field}
          unless $c->get_param($field) =~ /\S/;
    }

    unless ( $field_errors{em} ) {
        $field_errors{em} = _('Please enter a valid email address')
          if !mySociety::EmailUtil::is_valid_email( $c->get_param('em') );
    }

    %field_errors = (
        %field_errors,
        $c->cobrand->extra_contact_validation($c)
    );

    push @errors, _('Illegal ID')
      if $c->get_param('id') && !$c->stash->{problem}
          or $c->get_param('update_id') && !$c->stash->{update};

    push @errors, _('There was a problem showing this page. Please try again later.')
      if $c->get_param('message') && $c->get_param('message') =~ /\[url=|<a/;

    unshift @errors,
      _('There were problems with your report. Please see below.')
      if scalar keys %field_errors;

    if ( @errors or scalar keys %field_errors ) {
        $c->stash->{errors}       = \@errors;
        $c->stash->{field_errors} = \%field_errors;
        return 0;
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

    my $user = $c->cobrand->users->find( { email => $c->stash->{em} } );
    if ( $user ) {
        $c->stash->{user_admin_url} = $admin_url . '/users/' . $user->id;
        $c->stash->{user_reports_admin_url} = $admin_url . '/reports?search=' . $user->email;

        my $user_latest_problem = $user->latest_visible_problem();
        if ( $user_latest_problem) {
            $c->stash->{user_latest_report_admin_url} = $admin_url . '/report_edit/' . $user_latest_problem->id;
        }
    }

    if ( $c->stash->{update} ) {

        $c->stash->{problem_url} = $base_url . $c->stash->{update}->url;
        $c->stash->{admin_url} = $admin_url . '/update_edit/' . $c->stash->{update}->id;
        $c->stash->{complaint} = sprintf(
            "Complaint about update %d on report %d",
            $c->stash->{update}->id,
            $c->stash->{update}->problem_id,
        );
    }
    elsif ( $c->stash->{problem} ) {

        $c->stash->{problem_url} = $base_url . '/report/' . $c->stash->{problem}->id;
        $c->stash->{admin_url} = $admin_url . '/report_edit/' . $c->stash->{problem}->id;
        $c->stash->{complaint} = sprintf(
            "Complaint about report %d",
            $c->stash->{problem}->id,
        );

        # flag this so it's automatically listed in the admin interface
        $c->stash->{problem}->flagged(1);
        $c->stash->{problem}->update;
    }

    my @extra = grep { /^extra\./ } keys %{$c->req->params};
    foreach (@extra) {
        my $param = $c->get_param($_);
        my ($field_name) = /extra\.(.*)/;
        $c->stash->{message} = "\u$field_name: $param\n\n" . $c->stash->{message};
    }

    return 1;
}

=head2 setup_request

Pulls things from request into stash and adds other information
generally required to stash

=cut

sub setup_request : Private {
    my ( $self, $c ) = @_;

    my $email = $c->cobrand->contact_email;
    $email =~ s/\@/&#64;/;
    $c->stash->{contact_email} = FixMyStreet::Template::SafeString->new($email);

    for my $param (qw/em subject message/) {
        $c->stash->{$param} = $c->get_param($param);
    }

    # name is already used in the stash for the app class name
    $c->stash->{form_name} = $c->get_param('name');

    my $s = encode_base64(pack("N", time() + 10), '');
    $s =~ s/=+$//;
    $c->stash->{s} = $s;

    return 1;
}

=head2 send_email

Sends the email

=cut

sub send_email : Private {
    my ( $self, $c ) = @_;

    my $recipient      = $c->cobrand->contact_email;
    my $recipient_name = $c->cobrand->contact_name();

    if (my $localpart = $c->get_param('recipient')) {
        $recipient = join('@', $localpart, FixMyStreet->config('EMAIL_DOMAIN'));
    }

    $c->stash->{host} = $c->req->header('HOST');
    $c->stash->{ip}   = $c->req->address;
    $c->stash->{ip} .=
      $c->req->header('X-Forwarded-For')
      ? ' ( forwarded from ' . $c->req->header('X-Forwarded-For') . ' )'
      : '';

    my $from = [ $c->stash->{em}, $c->stash->{form_name} ];
    my $params = {
        to => [ [ $recipient, _($recipient_name) ] ],
        user_agent => $c->req->user_agent,
    };
    if (FixMyStreet::Email::test_dmarc($c->stash->{em})) {
        $params->{'Reply-To'} = [ $from ];
        $params->{from} = [ $recipient, $c->stash->{form_name} ];
    } else {
        $params->{from} = $from;
    }

    $c->stash->{success} = $c->send_email('contact.txt', $params);

    return 1;
}

=head2 redirect_on_success

Redirect to a custom URL if one was provided

=cut

sub redirect_on_success : Private {
    my ( $self, $c ) = @_;

    if (my $success_url = $c->get_param('success_url')) {
        $c->res->redirect($success_url);
        $c->detach;
    }

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
