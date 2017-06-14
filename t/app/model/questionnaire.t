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
        send_email => 1,
    },
    {
        state => 'unable to fix',
        send_email => 1,
    },
    {
        state => 'not responsible',
        send_email => 1,
    },
    {
        state => 'closed',
        send_email => 1,
    },
) {
    subtest "correct questionnaire behviour for state $test->{state}" => sub {
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

done_testing();
