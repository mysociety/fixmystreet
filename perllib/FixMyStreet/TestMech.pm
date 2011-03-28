package FixMyStreet::TestMech;
use base qw(Test::WWW::Mechanize::Catalyst Test::Builder::Module);

use strict;
use warnings;

BEGIN {
    use FixMyStreet;
    FixMyStreet->test_mode(1);
}

use Test::WWW::Mechanize::Catalyst 'FixMyStreet::App';
use Test::More;
use Web::Scraper;
use Carp;
use Email::Send::Test;
use Digest::SHA1 'sha1_hex';

=head1 NAME

FixMyStreet::TestMech - T::WWW::M:C but with FMS specific smarts

=head1 DESCRIPTION

This module subclasses L<Test::WWW::Mechanize::Catalyst> and adds some
FixMyStreet specific smarts - such as the ability to scrape the resulting page
for form error messages.

Note - using this module puts L<FixMyStreet::App> into test mode - so for
example emails will not get sent.

=head1 METHODS

=head2 check_not_logged_in, check_logged_in

    $bool = $mech->check_not_logged_in();
    $bool = $mech->check_logged_in();

Check that the current mech is not logged or logged in as a user. Produces test output.
Returns true test passed, false otherwise.

=cut

sub not_logged_in_ok {
    my $mech = shift;
    $mech->builder->ok( $mech->get('/auth/check_auth')->code == 401,
        "not logged in" );
}

sub logged_in_ok {
    my $mech = shift;
    $mech->builder->ok( $mech->get('/auth/check_auth')->code == 200,
        "logged in" );
}

=head2 log_in_ok

    $user = $mech->log_in_ok( $email_address );

Log in with the email given. If email does not match an account then create one.

=cut

sub log_in_ok {
    my $mech  = shift;
    my $email = shift;

    my $user =
      FixMyStreet::App->model('DB::User')
      ->find_or_create( { email => $email } );
    ok $user, "found/created user for $email";

    # store the old password and then change it
    my $old_password_sha1 = $user->password;
    $user->update( { password => sha1_hex('secret') } );

    # log in
    $mech->get_ok('/auth');
    $mech->submit_form_ok(
        { with_fields => { email => $email, password => 'secret' } },
        "login using form" );
    $mech->logged_in_ok;

    # restore the password (if there was one)
    $user->update( { password => $old_password_sha1 } ) if $old_password_sha1;

    return $user;
}

=head2 log_out_ok

    $bool = $mech->log_out_ok(  );

Log out the current user

=cut

sub log_out_ok {
    my $mech = shift;
    $mech->get_ok('/auth/logout');
    $mech->not_logged_in_ok;
}

sub delete_user {
    my $mech = shift;
    my $user = shift;

    $mech->log_out_ok;
    ok( $_->delete, "delete problem " . $_->title )    #
      for $user->problems;
    ok $user->delete, "delete test user " . $user->email;

    return 1;
}

=head2 clear_emails_ok

    $bool = $mech->clear_emails_ok();

Clear the email queue.

=cut

sub clear_emails_ok {
    my $mech = shift;
    Email::Send::Test->clear;
    $mech->builder->ok( 1, 'cleared email queue' );
    return 1;
}

=head2 email_count_is

    $bool = $mech->email_count_is( $number );

Check that the number of emails in queue is correct.

=cut

sub email_count_is {
    my $mech = shift;
    my $number = shift || 0;

    $mech->builder->is_num( scalar( Email::Send::Test->emails ),
        $number, "checking for $number email(s) in the queue" );
}

=head2 get_email

    $email = $mech->get_email;

In scalar context returns first email in queue and fails a test if there are not exactly one emails in the queue.

In list context returns all the emails (or none).

=cut

sub get_email {
    my $mech   = shift;
    my @emails = Email::Send::Test->emails;

    return @emails if wantarray;

    $mech->email_count_is(1) || return undef;
    return $emails[0];
}

=head2 form_errors

    my $arrayref = $mech->form_errors;

Find all the form errors on the current page and return them in page order as an
arrayref of TEXTs. If none found return empty arrayref.

=cut

sub form_errors {
    my $mech   = shift;
    my $result = scraper {
        process 'div.form-error', 'errors[]', 'TEXT';
    }
    ->scrape( $mech->response );
    return $result->{errors} || [];
}

=head2 pc_alternatives

    my $arrayref = $mech->pc_alternatives;

Find all the suggestions for near matches for a location. Return text presented to user as arrayref, empty arrayref if none found.

=cut

sub pc_alternatives {
    my $mech   = shift;
    my $result = scraper {
        process 'ul.pc_alternatives li', 'pc_alternatives[]', 'TEXT';
    }
    ->scrape( $mech->response );
    return $result->{pc_alternatives} || [];
}

=head2 extract_location

    $hashref = $mech->extract_location(  );

Extracts the location from the current page. Looks for inputs with the names
C<pc>, C<latitude> and C<longitude> and returns their values in a hashref with
those keys. If no values found then the values in hashrof are C<undef>.

=cut

sub extract_location {
    my $mech = shift;

    my $result = scraper {
        process 'input[name="pc"]',        pc        => '@value';
        process 'input[name="latitude"]',  latitude  => '@value';
        process 'input[name="longitude"]', longitude => '@value';
    }
    ->scrape( $mech->response );

    return {
        pc        => undef,
        latitude  => undef,
        longitude => undef,
        %$result
    };
}

=head2 visible_form_values

    $hashref = $mech->visible_form_values(  );

Return all the visible form values on the page - ie not the hidden ones.

=cut

sub visible_form_values {
    my $mech = shift;

    my @forms = $mech->forms;

    # insert form filtering here (eg ignore login form)

    croak "Found no forms - can't continue..."
      unless @forms;
    croak "Found several forms - don't know which to use..."
      if @forms > 1;

    my $form = $forms[0];

    my @visible_fields =
      grep { ref($_) ne 'HTML::Form::SubmitInput' }
      grep { ref($_) ne 'HTML::Form::ImageInput' }
      grep { ref($_) ne 'HTML::Form::TextInput' || $_->type ne 'hidden' }
      $form->inputs;

    my @visible_field_names = map { $_->name } @visible_fields;

    my %params = map { $_ => $form->value($_) } @visible_field_names;

    return \%params;
}

1;
