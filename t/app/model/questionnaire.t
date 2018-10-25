package FixMyStreet::Cobrand::Tester;

use parent 'FixMyStreet::Cobrand::Default';

sub send_questionnaire {
    my ($self, $row) = @_;
    return $row->latitude == 1;
}

package main;

use FixMyStreet;
use FixMyStreet::TestMech;

my $user = FixMyStreet::DB->resultset('User')->find_or_create( { email => 'test@example.com' } );

my $problem = FixMyStreet::DB->resultset('Problem')->create(
    {
        postcode     => 'EH99 1SP',
        latitude     => 1,
        longitude    => 1,
        areas        => 1,
        title        => 'to be sent',
        detail       => 'detail',
        used_map     => 1,
        user_id      => 1,
        name         => 'A Name',
        state        => 'confirmed',
        service      => '',
        cobrand      => 'default',
        cobrand_data => '',
        confirmed    => \"current_timestamp - '5 weeks'::interval",
        whensent     => \"current_timestamp - '5 weeks'::interval",
        user         => $user,
        anonymous    => 0,
    }
);

my $mech = FixMyStreet::TestMech->new;

for my $test (
    {
        state => 'unconfirmed',
        send_email => 0,
    },
    {
        state => 'partial',
        send_email => 0,
    },
    {
        state => 'hidden',
        send_email => 0,
    },
    {
        state => 'confirmed',
        send_email => 1,
    },
    {
        state => 'investigating',
        send_email => 1,
    },
    {
        state => 'planned',
        send_email => 1,
    },
    {
        state => 'action scheduled',
        send_email => 1,
    },
    {
        state => 'in progress',
        send_email => 1,
    },
    {
        state => 'fixed',
        send_email => 1,
    },
    {
        state => 'fixed - council',
        send_email => 1,
    },
    {
        state => 'fixed - user',
        send_email => 1,
    },
    {
        state => 'duplicate',
        send_email => 0,
    },
    {
        state => 'unable to fix',
        send_email => 0,
    },
    {
        state => 'not responsible',
        send_email => 0,
    },
    {
        state => 'closed',
        send_email => 0,
    },
) {
    subtest "correct questionnaire behaviour for state $test->{state}" => sub {
        $problem->discard_changes;
        $problem->state( $test->{state} );
        $problem->send_questionnaire( 1 );
        $problem->update;

        $problem->questionnaires->delete;

        $mech->email_count_is(0);

        FixMyStreet::DB->resultset('Questionnaire')
          ->send_questionnaires( { site => 'fixmystreet' } );

        $mech->email_count_is( $test->{send_email} );

        $mech->clear_emails_ok();
    }
}

for my $test (
    { latitude => 2, emails => 0, },
    { latitude => 1, emails => 1, },
) {
    subtest "test cobrand questionnaire send override, expecting $test->{emails} email" => sub {
        FixMyStreet::override_config {
            ALLOWED_COBRANDS => 'tester',
        }, sub {
            $problem->latitude($test->{latitude});
            $problem->send_questionnaire(1);
            $problem->state('confirmed');
            $problem->update;
            $problem->questionnaires->delete;

            $mech->email_count_is(0);
            FixMyStreet::DB->resultset('Questionnaire')->send_questionnaires( { site => 'tester' } );
            $mech->email_count_is($test->{emails});
            $mech->clear_emails_ok();

            $problem->discard_changes;
            is $problem->send_questionnaire, 0;
        };
    };
}

done_testing();
