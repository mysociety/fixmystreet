use FixMyStreet::TestMech;
use t::Mock::Stripe;

my $mech = FixMyStreet::TestMech->new;

my $body = $mech->create_body_ok(2608, 'South Gloucestershire Council');
$mech->create_contact_ok(body_id => $body->id, category => 'Potholes', email => 'potholes');
$mech->create_contact_ok(body_id => $body->id, category => 'Grass cutting', email => 'grass');

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'fixmystreet',
    COBRAND_FEATURES => {
        parishes => {
            fixmystreet => 1,
        },
        stripe => {
            fixmystreet => {
                public_key => 'public',
                secret_key => 'secret',
                tax_rate => 'tax',
                price_id => 'price',
            }
        },
        parish_signup_email => {
            fixmystreet => 'parishes@example.com'
        }
    },
    MAPIT_URL => 'http://mapit.uk/',
}, sub {
    subtest 'Parishes index page works and shows form' => sub {
        $mech->get_ok('/parishes');
        $mech->submit_form_ok({
            with_fields => {
                name => 'Test User',
                email => 'test@example.com',
                parish => '53956',
            },
        });
        $mech->content_contains('Grass cutting', 'Higher level category shown');
        $mech->content_contains('Potholes');
        $mech->submit_form_ok({
            form_number => 2,
            fields => {
                'categories.0.name' => 'Grass cutting',
                'categories.1.name' => 'Abbey playing field',
                'categories.2.name' => 'Broken public bench',
            },
        });
        $mech->content_contains('Grass cutting; Abbey playing field; Broken public bench');
        my $mech2 = $mech->clone;
        $mech2->submit_form_ok({ with_fields => { payment => 'Continue to payment' } });
        is $mech2->res->previous->code, 302, 'payments issues a redirect';
        is $mech2->res->previous->header('Location'), "https://example.org/faq", "redirects to payment gateway";
        $mech->get_ok('/parishes/pay_complete?session=SESSIONID');
        my $text = $mech->get_text_body_from_email;
        like $text, qr/A new user has signed up to FixMyStreet for Parishes/, "signup admin email sent";
        like $text, qr/Parish: Abbey Dore/, "signup admin email contains parish name";
    };
    subtest 'View admin' => sub {
        $mech->clear_emails_ok;
        $mech->get_ok('/parishes/admin');
        $mech->submit_form_ok({ with_fields => { username => 'test@example.com' }, button => 'sign_in_by_code' });
        my $link = $mech->get_link_from_email;
        $mech->get_ok($link);
        $mech->content_contains('Abbey Dore');
        $mech->content_contains('Abbey playing field');
    };
};

done_testing();
