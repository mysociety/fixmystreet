use FixMyStreet::TestMech;
use Test::MockModule;
use CGI::Simple;
use FixMyStreet::Cobrand::Enfield;
use FixMyStreet::Script::Reports;

my $mech = FixMyStreet::TestMech->new;

my $body = $mech->create_body_ok(2495, 'Enfield Council',
    { send_method => 'Open311', cobrand => 'enfield',
    api_key => 'key', endpoint => 'endpoint', jurisdiction => 'j', });

$mech->create_contact_ok( body => $body, category => 'Other', email => 'OTHER' );

my $gc = Test::MockModule->new('FixMyStreet::Geocode');
$gc->mock('cache', sub {
    my $type = shift;
    return {
        results => [
            { LPI => {
                  "UPRN" => "uprn",
                  "USRN" => "usrn",
            } }
        ],
    };
});

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'fixmystreet', 'enfield' ],
    BASE_URL => 'http://www.fixmystreet.com',
    STAGING_FLAGS => {
        send_reports => 1,
    },
    COBRAND_FEATURES => {
        open311_email => {
            enfield => 'extraemail@example.org',
        },
        os_places_api_key => {
            enfield => 'KEY',
        },
    }
}, sub {
    my $enfield = FixMyStreet::Cobrand::Enfield->new;

    subtest 'Post normal report' => sub {
        my ($p) = $mech->create_problems_for_body(1, $body, 'Title');

        FixMyStreet::Script::Reports::send();

        $p->discard_changes;
        is $p->get_extra_field_value('usrn'), 'usrn';

        my $req = Open311->test_req_used;
        my $cgi = CGI::Simple->new($req->content);
        is $cgi->param('attribute[title]'), $p->title;
        is $cgi->param('attribute[usrn]'), 'usrn';

        my $email = $mech->get_email;
        is $email->header('To'), 'FixMyStreet <extraemail@example.org>';
        like $email->as_string, qr/USRN: usrn/;
    };

    subtest 'Post cemetery report' => sub {
        my ($p) = $mech->create_problems_for_body(1, $body, 'Title', {
        });
        $p->update_extra_field({ name => 'pac', value => 1 });
        $p->update;
        # email sent post

        FixMyStreet::Script::Reports::send();

        $p->discard_changes;
        is $p->get_extra_field_value('uprn'), 'uprn';

        my $req = Open311->test_req_used;
        my $cgi = CGI::Simple->new($req->content);
        is $cgi->param('attribute[title]'), $p->title;
        is $cgi->param('attribute[uprn]'), 'uprn';
    };
};

done_testing();
