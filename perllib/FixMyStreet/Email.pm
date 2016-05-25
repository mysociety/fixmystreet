package FixMyStreet::Email::Error;

use Error qw(:try);

@FixMyStreet::Email::Error::ISA = qw(Error::Simple);

package FixMyStreet::Email;

use Email::MIME;
use Encode;
use POSIX qw();
use Template;
use Digest::HMAC_SHA1 qw(hmac_sha1_hex);
use Text::Wrap;
use mySociety::Locale;
use mySociety::Random qw(random_bytes);
use Utils::Email;
use FixMyStreet;
use FixMyStreet::DB;
use FixMyStreet::EmailSend;

sub test_dmarc {
    my $email = shift;
    return if FixMyStreet->test_mode;
    return Utils::Email::test_dmarc($email);
}

sub hash_from_id {
    my ($type, $id) = @_;
    my $secret = FixMyStreet::DB->resultset('Secret')->get;
    # Make sure the ID is stringified, a number is treated differently
    return substr(hmac_sha1_hex("$type-$id", $secret), 0, 8);
}

sub generate_verp_token {
    my ($type, $id) = @_;
    my $hash = hash_from_id($type, $id);
    return "$type-$id-$hash";
}

sub check_verp_token {
    my ($token) = @_;
    $token = lc($token);
    $token =~ s#[./_]##g;

    my ($type, $id, $hash) = $token =~ /(report|alert)-([a-z0-9]+)-([a-z0-9]+)/;
    return unless $type;

    $hash =~ tr/lo/10/;
    return unless hash_from_id($type, $id) eq $hash;

    return ($type, $id);
}

sub is_abuser {
    my ($schema, $to) = @_;

    my $email;
    if (ref($to) eq 'ARRAY') {
        if (ref($to->[0]) eq 'ARRAY') {
            $email = $to->[0][0];
        } else {
            $email = $to->[0];
        }
    } else {
        $email = $to;
    }

    my ($domain) = $email =~ m{ @ (.*) \z }x;
    return $schema->resultset('Abuse')->search( { email => [ $email, $domain ] } )->first;
}

sub _render_template {
    my ($tt, $template, $vars, %options) = @_;
    my $var;
    $tt->process($template, $vars, \$var);
    return $var;
}

sub send_cron {
    my ( $schema, $template, $vars, $hdrs, $env_from, $nomail, $cobrand, $lang_code ) = @_;

    my $sender = FixMyStreet->config('DO_NOT_REPLY_EMAIL');
    $env_from ||= $sender;
    if (!$hdrs->{From}) {
        my $sender_name = $cobrand->contact_name;
        $hdrs->{From} = [ $sender, _($sender_name) ];
    }

    return 1 if is_abuser($schema, $hdrs->{To});

    $hdrs->{'Message-ID'} = sprintf('<fms-cron-%s-%s@%s>', time(),
        unpack('h*', random_bytes(5, 1)), FixMyStreet->config('EMAIL_DOMAIN')
    );

    my $tt = Template->new({
        ENCODING => 'utf8',
        INCLUDE_PATH => [
            FixMyStreet->path_to( 'templates', 'email', $cobrand->moniker, $lang_code )->stringify,
            FixMyStreet->path_to( 'templates', 'email', $cobrand->moniker )->stringify,
            FixMyStreet->path_to( 'templates', 'email', 'default' )->stringify,
        ],
    });
    $vars->{signature} = _render_template($tt, 'signature.txt', $vars);
    $vars->{site_name} = Utils::trim_text(_render_template($tt, 'site-name.txt', $vars));
    $hdrs->{_body_} = _render_template($tt, $template, $vars);

    my $email = mySociety::Locale::in_gb_locale { construct_email($hdrs) };

    if ($nomail) {
        print $email->as_string;
        return 1; # Failure
    } else {
        my $result = FixMyStreet::EmailSend->new({ env_from => $env_from })->send($email);
        return $result ? 0 : 1;
    }
}

=item construct_email SPEC

Construct an email message according to SPEC, which is an associative array
containing elements as given below. Returns an Email::MIME email.

=over 4

=item _body_

Body text. The first line of the template will be interpreted as contents of
the Subject: header of the mail if it begins with the literal string 'Subject:
' followed by a blank line. The text will be word-wrapped to produce lines of
appropriate length.

=item _attachments_

An arrayref of hashrefs that can be passed to Email::MIME.

=item To

Contents of the To: header, as a literal UTF-8 string or an array of addresses
or [address, name] pairs.

=item From

Contents of the From: header, as an email address or an [address, name] pair.

=item Cc

Contents of the Cc: header, as for To.

=item Reply-To

Contents of the Reply-To: header, as for To.

=item Subject

Contents of the Subject: header, as a UTF-8 string.

=item I<any other element>

interpreted as the literal value of a header with the same name.

=back

If no Date is given, the current date is used. If no To is given, then the
string "Undisclosed-Recipients: ;" is used. It is an error to fail to give a
templated body, From or Subject (perhaps from the template).

=cut
sub construct_email ($) {
    my $p = shift;

    throw FixMyStreet::Email::Error("Must specify '_body_'") if !exists($p->{_body_});

    my $body = $p->{_body_};
    my $subject;
    if ($body =~ m#^Subject: ([^\n]*)\n\n#s) {
        $subject = $1;
        $body =~ s#^Subject: ([^\n]*)\n\n##s;
    }

    $body =~ s/\r\n/\n/gs;
    $body =~ s/^\s+$//mg; # Note this also reduces any gap between paragraphs of >1 blank line to 1
    $body =~ s/\s+$//;

    # Merge paragraphs into their own line.  Two blank lines separate a
    # paragraph. End a line with two spaces to force a linebreak.

    # regex means, "replace any line ending that is neither preceded (?<!\n)
    # nor followed (?!\n) by a blank line with a single space".
    $body =~ s#(?<!\n)(?<!  )\n(?!\n)# #gs;

    # Wrap text to 72-column lines.
    local($Text::Wrap::columns) = 69;
    local($Text::Wrap::huge) = 'overflow';
    local($Text::Wrap::unexpand) = 0;
    $body = Text::Wrap::wrap('', '', $body);
    $body =~ s/^\s+$//mg; # Do it again because of wordwrapping indented lines

    $p->{Subject} = $subject if defined($subject);

    if (!exists($p->{Subject})) {
        # XXX Try to find out what's causing this very occasionally
        (my $error = $body) =~ s/\n/ | /g;
        $error = "missing field 'Subject' in MESSAGE - $error";
        throw FixMyStreet::Email::Error($error);
    }
    throw FixMyStreet::Email::Error("missing field 'From' in MESSAGE") unless exists($p->{From});

    # Construct email headers
    my %hdr;

    foreach my $h (grep { exists($p->{$_}) } qw(To Cc Reply-To)) {
        if (ref($p->{$h}) eq '') {
            # Interpret as a literal string in UTF-8, so all we need to do is
            # escape it.
            $hdr{$h} = $p->{$h};
        } elsif (ref($p->{$h}) eq 'ARRAY') {
            # Array of addresses or [address, name] pairs.
            $hdr{$h} = join(', ', map { mailbox($_, $h) } @{$p->{$h}});
        } else {
            throw FixMyStreet::Email::Error("Field '$h' in MESSAGE should be single value or an array");
        }
    }

    foreach my $h (grep { exists($p->{$_}) } qw(From Sender)) {
        $hdr{$h} = mailbox($p->{$h}, $h);
    }

    # Some defaults
    $hdr{To} ||= 'Undisclosed-recipients: ;';
    $hdr{Date} ||= POSIX::strftime("%a, %d %h %Y %T %z", localtime(time()));

    # Other headers, including Subject
    foreach (keys(%$p)) {
        $hdr{$_} = $p->{$_} if ($_ !~ /^_/ && !exists($hdr{$_}));
    }

    my $parts = [
        _mime_create(
            body_str => $body,
            attributes => {
                charset => 'utf-8',
                encoding => 'quoted-printable',
            },
        ),
    ];

    if ($p->{_attachments_}) {
        push @$parts, map { _mime_create(%$_) } @{$p->{_attachments_}};
    }

    my $email = Email::MIME->create(
        header_str => [ %hdr ],
        parts => $parts,
        attributes => {
            charset => 'utf-8',
        },
    );

    return $email;
}

# Handle being given a string, or an arrayref of [ name, email ]
sub mailbox {
    my ($e, $header) = @_;
    if (ref($e) eq '') {
        return $e;
    } elsif (ref($e) ne 'ARRAY' || @$e != 2) {
        throw FixMyStreet::Email::Error("'$header' field should be string or 2-element array");
    } else {
        return Email::Address->new($e->[1], $e->[0]);
    }
}

# Don't want Date/MIME-Version headers that Email::MIME adds to all parts
sub _mime_create {
    my %h = @_;
    my $e = Email::MIME->create(%h);
    $e->header_set('Date');
    $e->header_set('MIME-Version');
    return $e;
}

1;
