#!/usr/bin/env perl
#
# send-daemon.t
# FixMyStreet test for reports- and updates-sending daemon.

use warnings;
use v5.14;

use Class::Accessor::Fast;
use Test::MockModule;
use FixMyStreet::Script::SendDaemon;
use FixMyStreet::TestMech;

my $mech = FixMyStreet::TestMech->new;
my $body = $mech->create_body_ok(2514, 'Birmingham');
$mech->create_contact_ok(email => 'g@example.org', category => 'Graffiti', body => $body);
my ($p) = $mech->create_problems_for_body(1, $body->id, 'Title', { category => 'Graffiti', state => 'unconfirmed' });

package TestObj;
use base 'Class::Accessor::Fast';
TestObj->mk_ro_accessors(qw(debug verbose nomail));
package main;

my $opts = TestObj->new({ debug => 0, verbose => 0, nomail => 0 });
FixMyStreet::Script::SendDaemon::setverboselevel(-1); # Nothing

subtest 'Unconfirmed reports ignored' => sub {
    FixMyStreet::Script::SendDaemon::look_for_report($opts);
    $p->discard_changes;
    is $p->send_state, 'unprocessed';
    is $p->send_fail_count, 0;
};

$p->update({ state => 'confirmed' });

subtest 'Error in sending caught okay' => sub {
    my $mock = Test::MockModule->new('FixMyStreet::Cobrand::Default');
    $mock->mock('find_closest', sub {
        die q[Can't use string ("<h1>Server Error (500)</h1>")]
        . q[ as a HASH ref while "strict refs" in use ]
    });

    FixMyStreet::Script::SendDaemon::look_for_report($opts);

    # check that problem has send fail count > 0 etc.
    $p->discard_changes;
    is $p->send_fail_count, 1;
    is $p->send_state, 'unprocessed';
};

subtest 'Normal sending works' => sub {
    $p->update({ send_fail_count => 0 });
    is $p->whensent, undef;
    FixMyStreet::Script::SendDaemon::look_for_report($opts);
    $p->discard_changes;
    isnt $p->whensent, undef;
    is $p->send_state, 'sent';
};

# Update existing data
$body->update({ send_method => 'Open311', send_comments => 1, api_key => 'key', endpoint => 'endpoint', jurisdiction => 'jurisdiction' });
my $c = $mech->create_comment_for_problem($p, $p->user, $p->user->name, 'An update', 'f', 'confirmed', 'confirmed');

# Add another body for update testing
my $body2 = $mech->create_body_ok(2636, 'Isle of Wight');
$mech->create_contact_ok(email => 'g@example.org', category => 'Graffiti', body => $body2);
my ($p2) = $mech->create_problems_for_body(1, $body2->id, 'Title', { category => 'Graffiti' });
my $c2 = $mech->create_comment_for_problem($p2, $p->user, $p->user->name, 'An update', 'f', 'confirmed', 'confirmed');

subtest 'Unconfirmed update ignored' => sub {
    $c->update({ state => 'unconfirmed' });
    FixMyStreet::Script::SendDaemon::look_for_update($opts);
    $c->discard_changes;
    $c2->discard_changes;
    is $c->send_state, 'unprocessed', 'Unconfirmed update ignored';
    is $c2->send_state, 'processed', 'Non-Open311 update marked as processed';
    $c->update({ state => 'confirmed' });
};

$p->update({ external_id => 123, send_method_used => 'Open311' });

subtest 'Normal update sending works' => sub {
    my $mock = Test::MockModule->new('Open311');
    $mock->mock('post_service_request_update', sub { 456 });

    is $c->whensent, undef, 'No sent timestamp';
    FixMyStreet::Script::SendDaemon::look_for_update($opts);
    $c->discard_changes;
    isnt $c->whensent, undef, 'Has a sent timestamp';
    is $c->send_state, 'sent', 'Marked as sent';
    is $c->external_id, 456, 'Correct external ID';
};

subtest 'Multiple updates on same problem should send in order of confirmation' => sub {
    my $mock = Test::MockModule->new('Open311');
    $mock->mock('post_service_request_update', sub { 456 });

    my ($p3) = $mech->create_problems_for_body(
        1,
        $body->id,
        'Title',
        {   category         => 'Graffiti',
            whensent         => '\NOW()',
            send_state       => 'sent',
            external_id      => 999,
            send_method_used => 'Open311',
        }
    );

    my $c1_p3
        = $mech->create_comment_for_problem( $p3, $p3->user, $p3->user->name,
        'An update 1', 'f', 'confirmed', 'confirmed',
        { confirmed => '2024-12-11 15:30:00' } );
    my $c2_p3
        = $mech->create_comment_for_problem( $p3, $p3->user, $p3->user->name,
        'An update 2', 'f', 'confirmed', 'confirmed',
        { confirmed => '2024-12-11 15:31:00' } );
    my $c3_p3
        = $mech->create_comment_for_problem( $p3, $p3->user, $p3->user->name,
        'An update 3', 'f', 'confirmed', 'confirmed',
        { confirmed => '2024-12-11 15:32:00' } );

    my $countdown = 20; # Ran test 100 times and no failure, so seems a solid number
    my %pending = map { $_->id => $_ } ( $c1_p3, $c2_p3, $c3_p3 );
    my @sent;
    while ( $countdown && _check_updates( \%pending, \@sent ) ) {
        FixMyStreet::Script::SendDaemon::look_for_update($opts);
        $countdown--;
    }

    is_deeply \@sent, [ $c1_p3->id, $c2_p3->id, $c3_p3->id ],
        'comments sent in order';
};

sub _check_updates {
    my ( $pending, $sent ) = @_;

    my $unsent = 0;
    for ( values %$pending ) {
        $_->discard_changes;
        if ( $_->send_state eq 'unprocessed' ) {
            $unsent++;
        } elsif ( $_->send_state eq 'sent' ) {
            delete $pending->{ $_->id };
            push @$sent, $_->id;
        }
    }

    return $unsent;
}

done_testing;
