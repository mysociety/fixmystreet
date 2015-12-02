package FixMyStreet::Email;

use Encode;
use Template;
use mySociety::Email;
use mySociety::Locale;
use mySociety::Random qw(random_bytes);
use Utils::Email;
use FixMyStreet;
use FixMyStreet::EmailSend;

sub test_dmarc {
    my $email = shift;
    return if FixMyStreet->test_mode;
    return Utils::Email::test_dmarc($email);
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

sub send_cron {
    my ( $schema, $params, $env_from, $nomail, $cobrand, $lang_code ) = @_;

    my $sender = FixMyStreet->config('DO_NOT_REPLY_EMAIL');
    $env_from ||= $sender;
    if (!$params->{From}) {
        my $sender_name = $cobrand->contact_name;
        $params->{From} = [ $sender, _($sender_name) ];
    }

    return 1 if is_abuser($schema, $params->{To});

    $params->{'Message-ID'} = sprintf('<fms-cron-%s-%s@%s>', time(),
        unpack('h*', random_bytes(5, 1)), FixMyStreet->config('EMAIL_DOMAIN')
    );

    # This is all to set the path for the templates processor so we can override
    # signature and site names in emails using templates in the old style emails.
    # It's a bit involved as not everywhere we use it knows about the cobrand so
    # we can't assume there will be one.
    my $include_path = FixMyStreet->path_to( 'templates', 'email', 'default' )->stringify;
    if ( $cobrand ) {
        $include_path =
            FixMyStreet->path_to( 'templates', 'email', $cobrand->moniker )->stringify . ':'
            . $include_path;
        if ( $lang_code ) {
            $include_path =
                FixMyStreet->path_to( 'templates', 'email', $cobrand->moniker, $lang_code )->stringify . ':'
                . $include_path;
        }
    }
    my $tt = Template->new({
        INCLUDE_PATH => $include_path
    });
    my ($sig, $site_name);
    $tt->process( 'signature.txt', $params, \$sig );
    $sig = Encode::decode('utf8', $sig);
    $params->{_parameters_}->{signature} = $sig;

    $tt->process( 'site-name.txt', $params, \$site_name );
    $site_name = Utils::trim_text(Encode::decode('utf8', $site_name));
    $params->{_parameters_}->{site_name} = $site_name;

    $params->{_line_indent} = '';
    my $attachments = delete $params->{attachments};

    my $email = mySociety::Locale::in_gb_locale { mySociety::Email::construct_email($params) };

    $email = munge_attachments($email, $attachments) if $attachments;

    if ($nomail) {
        print $email;
        return 1; # Failure
    } else {
        my %model_args;
        if (!FixMyStreet->test_mode && $env_from eq FixMyStreet->config('CONTACT_EMAIL')) {
            $model_args{mailer} = 'FixMyStreet::EmailSend::ContactEmail';
        }
        my $result = FixMyStreet::EmailSend->new(%model_args)->send($email);
        return $result ? 0 : 1;
    }
}

sub munge_attachments {
    my ($message, $attachments) = @_;
    # $attachments should be an array_ref of things that can be parsed to Email::MIME,
    # for example
    #    [
    #      body => $binary_data,
    #      attributes => {
    #          content_type => 'image/jpeg',
    #          encoding => 'base64',
    #          filename => '1234.1.jpeg',
    #          name     => '1234.1.jpeg',
    #      },
    #      ...
    #    ]
    #
    # XXX: mySociety::Email::construct_email isn't using a MIME library and
    # requires more analysis to refactor, so for now, we'll simply parse the
    # generated MIME and add attachments.
    #
    # (Yes, this means that the email is constructed by Email::Simple, munged
    # manually by custom code, turned back into Email::Simple, and then munged
    # with Email::MIME.  What's your point?)

    require Email::MIME;
    my $mime = Email::MIME->new($message);
    $mime->parts_add([ map { Email::MIME->create(%$_)} @$attachments ]);
    my $data = $mime->as_string;

    # unsure why Email::MIME adds \r\n. Possibly mail client should handle
    # gracefully, BUT perhaps as the segment constructed by
    # mySociety::Email::construct_email strips to \n, they seem not to.
    # So we re-run the same regexp here to the added part.
    $data =~ s/\r\n/\n/gs;

    return $data;
}

1;
