use strict;
use warnings;
use utf8;

BEGIN {
    use FixMyStreet;
    FixMyStreet->test_mode(1);
}

use Email::MIME;
use Test::More;
use Test::LongString;

use Catalyst::Test 'FixMyStreet::App';

use Email::Send::Test;
use Path::Tiny;

use FixMyStreet::TestMech;
my $mech = FixMyStreet::TestMech->new;

my $c = ctx_request("/");

# set some values in the stash
$c->stash->{foo} = 'bar';

# clear the email queue
Email::Send::Test->clear;

# send the test email
ok $c->send_email( 'test.txt', { to => 'test@recipient.com' } ),
  "sent an email";

# check it got templated and sent correctly
my @emails = Email::Send::Test->emails;
is scalar(@emails), 1, "caught one email";

# Get the email, check it has a date and then strip it out
my $email_as_string = $mech->get_first_email(@emails);
my $email = Email::MIME->new($email_as_string);

my $expected_email_content =   path(__FILE__)->parent->child('send_email_sample.txt')->slurp;
my $name = FixMyStreet->config('CONTACT_NAME');
$name = "\"$name\"" if $name =~ / /;
my $sender = $name . ' <' . FixMyStreet->config('DO_NOT_REPLY_EMAIL') . '>';
$expected_email_content =~ s{CONTACT_EMAIL}{$sender};
my $expected_email = Email::MIME->new($expected_email_content);

is_deeply { $email->header_pairs }, { $expected_email->header_pairs }, 'MIME email headers ok';
is_string $email->body, $expected_email->body, 'email is as expected';

subtest 'MIME attachments' => sub {
    my $data = path(__FILE__)->parent->child('grey.gif')->slurp_raw;

    Email::Send::Test->clear;
    my @emails = Email::Send::Test->emails;
    is scalar(@emails), 0, "reset";

    ok $c->send_email( 'test.txt',
        { to => 'test@recipient.com',
          attachments => [
             {
                body => $data,
                attributes => {
                    filename => 'foo.gif',
                    content_type => 'image/gif',
                    encoding => 'quoted-printable',
                    name => 'foo.gif',
                },
             },
             {
                body => $data,
                attributes => {
                    filename => 'bar.gif',
                    content_type => 'image/gif',
                    encoding => 'quoted-printable',
                    name => 'bar.gif',
                },
             },
         ]
        } ), "sent an email with MIME attachments";

    @emails = $mech->get_email;
    is scalar(@emails), 1, "caught one email";

    my $email_as_string = $mech->get_first_email(@emails);
    my ($boundary) = $email_as_string =~ /boundary="([A-Za-z0-9.]*)"/ms;
    my $email = Email::MIME->new($email_as_string);

    my $expected_email_content = path(__FILE__)->parent->child('send_email_sample_mime.txt')->slurp;
    $expected_email_content =~ s{CONTACT_EMAIL}{$sender}g;
    $expected_email_content =~ s{BOUNDARY}{$boundary}g;
    my $expected_email = Email::MIME->new($expected_email_content);

    my @email_parts;
    $email->walk_parts(sub {
        my ($part) = @_;
        push @email_parts, [ { $part->header_pairs }, $part->body ];
    });
    my @expected_email_parts;
    $expected_email->walk_parts(sub {
        my ($part) = @_;
        push @expected_email_parts, [ { $part->header_pairs }, $part->body ];
    });
    is_deeply \@email_parts, \@expected_email_parts, 'MIME email text ok'
        or do {
            (my $test_name = $0) =~ s{/}{_}g;
            my $path = path("test-output-$test_name.tmp");
            $path->spew($email_as_string);
            diag "Saved output in $path";
        };
};

done_testing;
