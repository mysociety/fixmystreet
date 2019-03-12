#!/usr/bin/env perl

use FixMyStreet::TestMech;

my $mech = FixMyStreet::TestMech->new;

use_ok( 'Open311::PostServiceRequestUpdates' );

my $o = Open311::PostServiceRequestUpdates->new( site => 'fixmystreet.com' );

my $params = {
    send_method => 'Open311',
    send_comments => 1,
    api_key => 'KEY',
    endpoint => 'endpoint',
    jurisdiction => 'home',
};
my $bromley = $mech->create_body_ok(2482, 'Bromley', { %$params, send_extended_statuses => 1, id => 5 });
my $oxon = $mech->create_body_ok(2237, 'Oxfordshire', { %$params, id => 55 });
my $bucks = $mech->create_body_ok(2217, 'Buckinghamshire', $params);
my $lewisham = $mech->create_body_ok(2492, 'Lewisham', $params);

subtest 'Check Open311 params' => sub {
  FixMyStreet::override_config {
    ALLOWED_COBRANDS => ['fixmystreet', 'bromley', 'buckinghamshire', 'lewisham', 'oxfordshire'],
  }, sub {
    my $result = {
        endpoint => 'endpoint',
        jurisdiction => 'home',
        api_key => 'KEY',
        extended_statuses => undef,
    };
    my %conf = $o->open311_params($bromley);
    is_deeply \%conf, {
        %$result,
        extended_statuses => 1,
        endpoints => { service_request_updates => 'update.xml', update => 'update.xml' },
        fixmystreet_body => $bromley,
    }, 'Bromley params match';
    %conf = $o->open311_params($oxon);
    is_deeply \%conf, {
        %$result,
        use_customer_reference => 1,
        fixmystreet_body => $oxon,
    }, 'Oxfordshire params match';
    %conf = $o->open311_params($bucks);
    is_deeply \%conf, {
        %$result,
        mark_reopen => 1,
        fixmystreet_body => $bucks,
    }, 'Bucks params match';
    %conf = $o->open311_params($lewisham);
    is_deeply \%conf, {
        %$result,
        fixmystreet_body => $lewisham,
    }, 'Lewisham params match';
  };
};

my $other_user = $mech->create_user_ok('test2@example.com', title => 'MRS');

sub c {
    my ($p, $user) = @_;
    my $c = $mech->create_comment_for_problem($p, $user || $p->user, 'Name', 'Update text', 'f', 'confirmed', 'confirmed', { confirmed => \'current_timestamp' });
    return $c;
}

sub p_and_c {
    my ($body, $user) = @_;

    my $prob_params = { send_method_used => 'Open311', whensent => \'current_timestamp', external_id => 1 };
    my ($p) = $mech->create_problems_for_body(1, $body->id, 'Title', $prob_params);
    my $c = c($p, $user);
    return ($p, $c);
}

my ($p1, $c1) = p_and_c($bromley, $other_user);
my ($p2, $c2) = p_and_c($oxon);
my ($p3, $c3a) = p_and_c($bucks);
my $c3b = c($p3, $other_user);
my ($p4, $c4) = p_and_c($lewisham);

subtest 'Send comments' => sub {
  FixMyStreet::override_config {
    ALLOWED_COBRANDS => ['fixmystreet', 'bromley', 'buckinghamshire', 'lewisham', 'oxfordshire'],
  }, sub {
    $o->send;
    $c3a->discard_changes;
    is $c3a->extra, undef, 'Bucks update by owner was sent';
    $c3b->discard_changes;
    is $c3b->extra->{cobrand_skipped_sending}, 1, 'Bucks update by other was not';
    $c1->discard_changes;
    is $c1->extra->{title}, "MRS", 'Title set on Bromley update';
    $c2->discard_changes;
    is $c2->send_fail_count, 0, 'Oxfordshire update skipped entirely';
  };
};

subtest 'Oxfordshire gets an ID' => sub {
  FixMyStreet::override_config {
    ALLOWED_COBRANDS => ['fixmystreet', 'bromley', 'buckinghamshire', 'lewisham', 'oxfordshire'],
  }, sub {
    $p2->set_extra_metadata(customer_reference => 'ABC');
    $p2->update;
    $o->send;
    $c2->discard_changes;
    is $c2->send_fail_count, 1, 'Oxfordshire update tried to send, failed';
  };
};


done_testing();
