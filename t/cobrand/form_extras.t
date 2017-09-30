package FixMyStreet::Cobrand::Tester;
use parent 'FixMyStreet::Cobrand::FixMyStreet';

sub report_form_extras {
    ( { name => 'address', required => 1 }, { name => 'passport', required => 0 } )
}

# To allow a testing template override
sub path_to_web_templates {
    my $self = shift;
    return [
        FixMyStreet->path_to( 't/cobrand/form_extras/templates' )->stringify,
    ];
}

package main;

use FixMyStreet::TestMech;

# disable info logs for this test run
FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $mech = FixMyStreet::TestMech->new;

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ { tester => '.' } ],
    MAPIT_URL => 'http://mapit.uk/',
}, sub {
    $mech->get_ok('/around');
    $mech->submit_form_ok( { with_fields => { pc => 'EH1 1BB', } }, "submit location" );
    $mech->follow_link_ok( { text_regex => qr/skip this step/i, }, "follow 'skip this step' link" );
    $mech->submit_form_ok( {
            button      => 'submit_register',
            with_fields => {
                title => 'Test Report',
                detail => 'Test report details.',
                name => 'Joe Bloggs',
                may_show_name => '1',
                username => 'test-1@example.com',
                passport => '123456',
                password_register => '',
            }
        },
        "submit details without address, with passport",
    );
    $mech->content_like(qr{<label for="form_address">Address</label>\s*<p class='form-error'>This information is required</p>}, 'Address is required');
    $mech->content_contains('value="123456" name="passport"', 'Passport number reshown');

    $mech->submit_form_ok( {
            button      => 'submit_register',
            with_fields => {
                address => 'My address',
            }
        },
        "submit details, now with address",
    );
    $mech->content_contains('Now check your email');

    my $problem = FixMyStreet::DB->resultset('Problem')->search({}, { order_by => '-id' })->first;
    is $problem->get_extra_metadata('address'), 'My address', 'Address is stored';
    is $problem->get_extra_metadata('passport'), '123456', 'Passport number is stored';
};

END {
    done_testing();
}
