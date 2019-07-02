package FixMyStreet::Cobrand::Tester;
use parent 'FixMyStreet::Cobrand::FixMyStreet';

sub report_form_extras {
    (
        { name => 'address', required => 1 },
        { name => 'passport', required => 0, validator => sub { die "Invalid number\n" if $_[0] && $_[0] !~ /^P/; return $_[0] } },
    )
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
                password_register => '',
            }
        },
        "submit details without address or passport",
    );
    $mech->content_like(qr{<label for="form_address">Address</label>\s*<p class='form-error'>This information is required</p>}, 'Address is required');
    $mech->content_lacks("<p class='form-error'>Invalid number", 'Passport is optional');

    $mech->submit_form_ok( {
            button      => 'submit_register',
            with_fields => {
                passport => '123456',
            }
        },
        "submit details with bad passport",
    );
    $mech->content_like(qr{<label for="form_address">Address</label>\s*<p class='form-error'>This information is required</p>}, 'Address is required');
    $mech->content_like(qr{<p class='form-error'>Invalid number}, 'Passport format wrong');
    $mech->content_contains('value="123456" name="passport"', 'Passport number reshown');

    $mech->submit_form_ok( {
            button      => 'submit_register',
            with_fields => {
                address => 'My address',
            }
        },
        "submit details, now with address",
    );
    $mech->content_lacks('This information is required', 'Address is present');
    $mech->content_like(qr{<p class='form-error'>Invalid number}, 'Passport format wrong');
    $mech->content_contains('value="123456" name="passport"', 'Passport number reshown');

    $mech->submit_form_ok( {
            button      => 'submit_register',
            with_fields => {
                passport => 'P123456',
            }
        },
        "submit details with correct passport",
    );
    $mech->content_contains('Now check your email');

    my $problem = FixMyStreet::DB->resultset('Problem')->search({}, { order_by => { -desc => 'id' } })->first;
    is $problem->get_extra_metadata('address'), 'My address', 'Address is stored';
    is $problem->get_extra_metadata('passport'), 'P123456', 'Passport number is stored';
};

END {
    done_testing();
}
