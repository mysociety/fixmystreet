package FixMyStreet::TestMech;
use parent qw(Test::WWW::Mechanize::Catalyst Test::Builder::Module);

use FixMyStreet::Test;

sub import {
    strict->import;
    warnings->import(FATAL => 'all');
    utf8->import;
    Test::More->export_to_level(1);
}

use Encode;
use Test::WWW::Mechanize::Catalyst 'FixMyStreet::App';
use t::Mock::MapIt;
use Test::More;
use Web::Scraper;
use Carp;
use FixMyStreet::Email::Sender;
use JSON::MaybeXS;

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

=head2 uniquify_email

Given an email address, will add the caller to it so that it can be unique per
file. You can pass a caller file in yourself if e.g. you're another function in
this file.

=cut

sub uniquify_email {
    my ($self, $email, $file) = @_;

    $file = (caller)[1] unless $file;
    (my $pkg = $file) =~ s{[/\.]}{}g;

    if ($email =~ /@/ && $email !~ /^pkg-/) {
        $email = "pkg-$pkg-$email";
    }
    return $email;
}

=head2 create_user_ok

    $user = $mech->create_user_ok( $email );

Create a test user (or find it and return if it already exists).

=cut

sub create_user_ok {
    my $self = shift;
    my ( $username, %extra ) = @_;

    $username = $self->uniquify_email($username, (caller)[1]);
    my $params = { %extra };
    $username =~ /@/ ? ($params->{email} = $username) : ($params->{phone} = $username);
    my $user = FixMyStreet::DB->resultset('User')->find_or_create($params);
    ok $user, "found/created user for $username";

    return $user;
}

=head2 log_in_ok

    $user = $mech->log_in_ok( $email_address );

Log in with the email/phone given. If email/phone does not match an account then create one.

=cut

sub log_in_ok {
    my $mech  = shift;
    my $username = shift;

    $mech->get_ok('/auth'); # Doing this here so schema cobrand set appropriately (for e.g. TfL password setting)

    $username = $mech->uniquify_email($username, (caller)[1]);
    my $user = $mech->create_user_ok($username);

    # remember the old password and then change it to a known one
    my $old_password = $user->password || '';
    $user->update( { password => 'secret' } );

    # log in
    $mech->submit_form_ok(
        { with_fields => { username => $username, password_sign_in => 'secret' } },
        "sign in using form" );
    $mech->logged_in_ok;

    # restore the password (if there was one)
    if ($old_password) {
        $user->password($old_password, 1);
        $user->update();

        # Belt and braces, check that the password has been correctly saved.
        die "password not correctly restored after log_in_ok"
            if $user->password ne $old_password;
    }

    return $user;
}

=head2 log_out_ok

    $bool = $mech->log_out_ok(  );

Log out the current user

=cut

sub log_out_ok {
    my $mech = shift;
    $mech->get_ok('/auth/sign_out');
    $mech->not_logged_in_ok;
}

=head2 delete_user

    $mech->delete_user( $user );
    $mech->delete_user( $email );
    $mech->delete_user( $phone );

Delete the current user, including linked objects like problems etc. Can be
either a user object or an email address.

=cut

sub delete_user {
    my $mech = shift;
    my $user_or_username = shift;

    my $user = ref $user_or_username ? $user_or_username : undef;
    $user = FixMyStreet::DB->resultset('User')->find( { email => $user_or_username } )
        unless $user;
    $user = FixMyStreet::DB->resultset('User')->find( { phone => $user_or_username } )
        unless $user;

    # If no user found we can't delete them
    return 1 unless $user;

    $mech->get('/auth/sign_out');

    for my $p ( $user->problems ) {
        $p->comments->delete;
        $p->questionnaires->delete;
        $p->user_planned_reports->delete;
        $p->delete;
    }
    for my $a ( $user->alerts ) {
        $a->alerts_sent->delete;
        $a->delete;
    }
    $_->delete for $user->comments;
    $_->delete for $user->admin_logs;
    $_->delete for $user->user_body_permissions;
    $user->delete;

    return 1;
}

=head2 clear_emails_ok

    $bool = $mech->clear_emails_ok();

Clear the email queue.

=cut

sub clear_emails_ok {
    my $mech = shift;
    FixMyStreet::Email::Sender->default_transport->clear_deliveries;
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

    $mech->builder->is_num( scalar( FixMyStreet::Email::Sender->default_transport->delivery_count ),
        $number, "checking for $number email(s) in the queue" );
}

=head2 get_email

    $email = $mech->get_email;

In scalar context returns first email in queue and fails a test if there are not exactly one emails in the queue.

In list context returns all the emails (or none).

=cut

sub get_email {
    my $mech   = shift;
    my @emails = FixMyStreet::Email::Sender->default_transport->deliveries;
    @emails = map { $_->{email}->object } @emails;

    return @emails if wantarray;

    $mech->email_count_is(1) || return undef;
    return $emails[0];
}

sub get_email_envelope {
    my $mech   = shift;
    my @emails = FixMyStreet::Email::Sender->default_transport->deliveries;
    @emails = map { $_->{envelope} } @emails;

    return @emails if wantarray;

    $mech->email_count_is(1) || return undef;
    return $emails[0];
}

sub get_text_body_from_email {
    my ($mech, $email, $obj) = @_;
    unless ($email) {
        $email = $mech->get_email;
        $mech->clear_emails_ok;
    }

    my $body;
    $email->walk_parts(sub {
        my $part = shift;
        return if $part->subparts;
        return if $part->content_type !~ m{text/plain};
        $body = $obj ? $part : $part->body_str;
        ok $body, "Found text body";
    });
    return $body;
}

sub get_link_from_email {
    my ($mech, $email, $multiple, $mismatch) = @_;
    unless ($email) {
        $email = $mech->get_email;
        $mech->clear_emails_ok;
    }

    my @links;
    $email->walk_parts(sub {
        my $part = shift;
        return if $part->subparts;
        return if $part->content_type !~ m{text/};
        if (@links) {
            # Must be an HTML part now, first two links are in header
            my @html_links = $part->body =~ m{https?://[^"]+}g;
            is $links[0], $html_links[2], 'HTML link matches text link' unless $mismatch;
        } else {
            @links = $part->body =~ m{https?://\S+}g;
            ok @links, "Found links in email '@links'";
        }
    });
    return $multiple ? @links : $links[0];
}

=head2 get_first_email

    $email = $mech->get_first_email(@emails);

Returns first email in queue as a string and fails a test if the mail doesn't have a date and epoch-containing Message-ID header.

=cut

sub get_first_email {
    my $mech = shift;
    my $email = shift or do { fail 'No email retrieved'; return };
    my $email_as_string = $email->as_string;
    ok $email_as_string =~ s{^Date:\s+\S.*?\r?\n}{}xmsg, "Found and stripped out date";
    ok $email_as_string =~ s{^Message-ID:\s+\S.*?\r?\n}{}xmsg, "Found and stripped out message ID (contains epoch)";
    return $email_as_string;
}

=head2 contains_or_lacks

Based upon boolean FLAG, checks that content contains or lacks TEXT.

=cut

sub contains_or_lacks {
    my ($mech, $flag, $text) = @_;
    $flag ? $mech->content_contains($text) : $mech->content_lacks($text);
}

=head2 page_errors

    my $arrayref = $mech->page_errors;

Find all the form errors on the current page and return them in page order as an
arrayref of TEXTs. If none found return empty arrayref.

=cut

sub page_errors {
    my $mech   = shift;
    my $result = scraper {
        process 'div.form-error, p.form-error, p.error, ul.error li', 'errors[]', 'TEXT';
    }
    ->scrape( $mech->response );
    my $err = $result->{errors} || [];
    my %seen = ();
    $err = [ grep { not $seen{$_}++ } @$err ];
    return $err;
}

=head2 import_errors

    my $arrayref = $mech->import_errors;

Takes the text output from the import post result and returns all the errors as
an arrayref.

=cut

sub import_errors {
    my $mech = shift;
    my @errors =    #
      grep { $_ }   #
      map { s{^ERROR:\s*(.*)$}{$1}g ? $_ : undef; }    #
      split m/\n+/, $mech->content;
    return \@errors;
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

=head2 extract_problem_meta

    $meta = $mech->extract_problem_meta;

Returns the problem meta information ( submitted by, at etc ) from a
problem report page

=cut

sub extract_problem_meta {
    my $mech = shift;

    my $result = scraper {
        process 'div#side p em', 'meta', 'TEXT';
        process '.problem-header p em', 'meta', 'TEXT';
        process '.problem-header p.report_meta_info', 'meta', 'TEXT';
    }
    ->scrape( $mech->response );

    my ($meta) = map { s/^\s+//; s/\s+$//; $_; } ($result->{meta});

    return $meta;
}

=head2 extract_problem_title

    $title = $mech->extract_problem_title;

Returns the problem title from a problem report page.

=cut

sub extract_problem_title {
    my $mech = shift;

    my $result = scraper {
        process 'div#side h1', 'title', 'TEXT';
        process '.problem-header h1', 'title', 'TEXT';
    }
    ->scrape( $mech->response );

    return $result->{title};
}

=head2 extract_problem_banner

    $banner = $mech->extract_problem_banner;

Returns the problem title from a problem report page. Returns a hashref with class and text.

=cut

sub extract_problem_banner {
    my $mech = shift;

    my $result = scraper {
        process 'div.banner', class => '@class';
        process 'div.banner > p', text => 'TEXT';
    }
    ->scrape( $mech->response );

    return $result;
}

=head2 extract_update_metas

    $metas = $mech->extract_update_metas;

Returns an array ref of all the update meta information on the page. Strips whitespace from
the start and end of all of them.

=cut

sub extract_update_metas {
    my $mech = shift;

    my $result = scraper {
        process 'div#updates div.problem-update p em', 'meta[]', 'TEXT';
        process '.item-list__update-text .meta-2', 'meta[]', 'TEXT';
    }
    ->scrape( $mech->response );

    my @metas = map { s/^\s+//; s/\s+$//; $_; } @{ $result->{meta} };

    return \@metas;
}

=head2 extract_problem_list

    $problems = $mech->extract_problem_list

Returns an array ref of all problem titles on a page featuring standard issue lists

=cut

sub extract_problem_list {
    my $mech = shift;

    my $result = scraper {
        process 'ul.item-list--reports li a h3', 'problems[]', 'TEXT';
    }->scrape( $mech->response );

    return $result->{ problems } || [];
}

=head2 visible_form_values

    $hashref = $mech->visible_form_values(  );

Return all the visible form values on the page - ie not the hidden ones.

=cut

sub visible_form_values {
    my $mech = shift;
    my $name = shift || '';

    my $form;

    if ($name) {
        for ( $mech->forms ) {
            $form = $_ if ( $_->attr('name') || '' ) eq $name;
        }
        croak "Can't find form named $name - can't continue..."
          unless $form;
    }
    else {
        my @forms =
          grep { ( $_->attr('name') || '' ) ne 'overrides_form' } # ignore overrides
          $mech->forms;

        croak "Found no forms - can't continue..."
          unless @forms;

        croak "Found several forms - don't know which to use..."
          if @forms > 1;

        $form = $forms[0];
    }

    my @visible_fields =
      grep { ref($_) ne 'HTML::Form::SubmitInput' }
      grep { ref($_) ne 'HTML::Form::ImageInput' }
      grep { ref($_) ne 'HTML::Form::TextInput' || $_->type ne 'hidden' }
      grep { !$_->disabled }
      $form->inputs;

    my @visible_field_names = map { $_->name } @visible_fields;

    my %params = map { $_ => $form->value($_) } @visible_field_names;

    return \%params;
}

=head2 get_ok_json

    $decoded = $mech->get_ok_json( $url );

Get the url, check that it was JSON and then decode and return the body.

=cut

sub get_ok_json {
    my $mech = shift;
    my $url  = shift;

    # try to get the response
    $mech->get_ok($url)
      || return undef;
    my $res = $mech->response;

    # check that the content-type of response is correct
    croak "Response was not JSON"
      unless $res->header('Content-Type') =~ m{^application/(?:[a-z]+\+)?json\b};

    return decode_json( $res->content );
}

sub delete_body {
    my $mech = shift;
    my $body = shift;

    $mech->delete_problems_for_body($body->id);
    $mech->delete_defect_type($_) for $body->defect_types;
    $mech->delete_contact($_) for $body->contacts;
    $mech->delete_user($_) for $body->users;
    $_->delete for $body->response_templates;
    $_->delete for $body->response_priorities;
    $body->body_areas->delete;
    $body->delete;
}

sub delete_contact {
    my $mech = shift;
    my $contact = shift;

    $contact->contact_response_templates->delete_all;
    $contact->contact_response_priorities->delete_all;
    $contact->delete;
}

sub delete_problems_for_body {
    my $mech = shift;
    my $body = shift;

    my $reports = FixMyStreet::DB->resultset('Problem')->search( { bodies_str => $body } );
    if ( $reports ) {
        for my $r ( $reports->all ) {
            $r->comments->delete;
            $r->questionnaires->delete;
        }
        $reports->delete;
    }
}

sub delete_defect_type {
    my $mech = shift;
    my $defect_type = shift;

    $defect_type->contact_defect_types->delete_all;
    $defect_type->delete;
}

sub delete_response_template {
    my $mech = shift;
    my $response_template = shift;

    $response_template->contact_response_templates->delete_all;
    $response_template->delete;
}

sub create_contact_ok {
    my $self = shift;
    my %contact_params = (
        state => 'confirmed',
        editor => 'Test',
        whenedited => \'current_timestamp',
        note => 'Created for test',
        @_
    );
    my $contact = FixMyStreet::DB->resultset('Contact')->find_or_create( \%contact_params );
    ok $contact, 'found/created contact ' . $contact->category;;
    return $contact;
}

sub create_body_ok {
    my ( $self, $area_id, $name, $params ) = @_;

    $params->{name} = $name;

    my $body = FixMyStreet::DB->resultset('Body');
    $body = $body->find_or_create( $params );
    ok $body, "found/created body $name";

    $body->body_areas->delete;
    FixMyStreet::DB->resultset('BodyArea')->find_or_create({
        area_id => $area_id,
        body_id => $body->id,
    });

    return $body;

}

sub create_problems_for_body {
    my ( $mech, $count, $body, $title, $params ) = @_;

    my $dt = $params->{dt} || DateTime->now();

    my $email = $mech->uniquify_email('test@example.com', (caller)[1]);
    my $user = $params->{user} ||
      FixMyStreet::DB->resultset('User')->find_or_create( { email => $email, name => 'Test User' } );

    delete $params->{user};
    delete $params->{dt};

    my @problems;

    while ($count) {
        my $default_params = {
            postcode           => 'SW1A 1AA',
            bodies_str         => $body,
            areas              => ',105255,11806,11828,2247,2504,',
            category           => 'Other',
            title              => "$title Test $count for $body",
            detail             => "$title Test $count for $body Detail",
            used_map           => 't',
            name               => 'Test User',
            anonymous          => 'f',
            state              => 'confirmed',
            confirmed          => $dt->ymd . ' ' . $dt->hms,
            lang               => 'en-gb',
            service            => '',
            cobrand            => 'default',
            cobrand_data       => '',
            send_questionnaire => 't',
            latitude           => '51.5016605453401',
            longitude          => '-0.142497580865087',
            user_id            => $user->id,
            photo              => '74e3362283b6ef0c48686fb0e161da4043bbcc97.jpeg',
        };

        my %report_params = ( %$default_params, %$params );

        my $problem =
          FixMyStreet::DB->resultset('Problem')->create( \%report_params );

        push @problems, $problem;
        $count--;
    }

    return @problems;
}

sub create_comment_for_problem {
    my ( $mech, $problem, $user, $name, $text, $anonymous, $state, $problem_state, $params ) = @_;
    $params ||= {};
    $params->{problem_id} = $problem->id;
    $params->{user_id} = $user->id;
    $params->{name} = $name;
    $params->{text} = $text;
    $params->{anonymous} = $anonymous;
    $params->{problem_state} = $problem_state;
    $params->{state} = $state;
    $params->{mark_fixed} = $problem_state && FixMyStreet::DB::Result::Problem->fixed_states()->{$problem_state} ? 1 : 0;
    $params->{confirmed} = \'current_timestamp' unless $params->{confirmed} || $state eq 'unconfirmed';

    FixMyStreet::App->model('DB::Comment')->create($params);
}

sub encoded_content {
    my $self = shift;
    return encode_utf8($self->content);
}

sub content_as_csv {
    my $self = shift;
    open my $data_handle, '<:encoding(utf-8)', \$self->encoded_content;
    my $csv = Text::CSV->new({ binary => 1 });
    my @rows;
    while (my $row = $csv->getline($data_handle)) {
        push @rows, $row;
    }
    return @rows;
}

1;
