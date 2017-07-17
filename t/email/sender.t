use FixMyStreet::Test;
use FixMyStreet::Email::Sender;
use Test::Exception;

# Specifically testing live email sending errors
FixMyStreet->test_mode(0);

subtest 'SMTP settings' => sub {
    FixMyStreet::override_config {
        SMTP_SMARTHOST => 'localhost',
        SMTP_TYPE => 'bad',
    }, sub {
        throws_ok { FixMyStreet::Email::Sender->send('test') }
            qr/Bad SMTP_TYPE config: is bad, should be tls, ssl, or blank/, 'Bad SMTP_TYPE throws';
    };

    FixMyStreet::override_config {
        SMTP_SMARTHOST => 'localhost',
        SMTP_TYPE => 'TLS',
    }, sub {
        throws_ok { FixMyStreet::Email::Sender->send('test') }
            qr/no recipients/, 'Upper case SMTP_TYPE passes, no recipients throws';
    };
};

subtest 'sendmail default' => sub {
    FixMyStreet::override_config {
        SMTP_SMARTHOST => '',
    }, sub {
        FixMyStreet::Email::Sender->reset_default_transport;
        throws_ok { FixMyStreet::Email::Sender->send('test') }
            qr/no recipients|couldn't find a sendmail/, 'Sendmail throws some form of error';
    };
};

done_testing();
