#!/usr/bin/env perl

use FixMyStreet::TestMech;
use Test::Output;

my $mech = FixMyStreet::TestMech->new;

use_ok( 'Open311::PostServiceRequestUpdates' );

my $o = Open311::PostServiceRequestUpdates->new;

my $params = {
    send_method => 'Open311',
    send_comments => 1,
    api_key => 'KEY',
    endpoint => '//endpoint/',
    jurisdiction => 'home',
};
my $bromley = $mech->create_body_ok(2482, 'Bromley', { %$params,
    endpoint => '//www.bromley.gov.uk/',
    send_extended_statuses => 1,
    can_be_devolved => 1, cobrand => 'bromley' });
my $oxon = $mech->create_body_ok(2237, 'Oxfordshire', { %$params, id => "5" . $bromley->id, cobrand => 'oxfordshire' });
my $bucks = $mech->create_body_ok(163793, 'Buckinghamshire', { %$params, cobrand => 'buckinghamshire' });
my $bromley_other = $mech->create_contact_ok(body_id => $bromley->id, category => 'Other', email => "OTHER", send_method => 'Open311', endpoint => '/devolved-endpoint/');
my $oxon_other = $mech->create_contact_ok(body_id => $oxon->id, category => 'Other', email => "OTHER");

subtest 'Check Open311 params' => sub {
  FixMyStreet::override_config {
    ALLOWED_COBRANDS => ['fixmystreet', 'bromley', 'buckinghamshire', 'oxfordshire'],
  }, sub {
    my $result = {
        endpoint => '//endpoint/',
        jurisdiction => 'home',
        api_key => 'KEY',
        extended_statuses => undef,
    };
    my %conf = $o->open311_params($bromley);
    is_deeply \%conf, {
        %$result,
        endpoint => '//www.bromley.gov.uk/',
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
  };
};

my $other_user = $mech->create_user_ok('test2@example.com', title => 'MRS');

sub c {
    my ($p, $user) = @_;
    my $c = $mech->create_comment_for_problem($p, $user || $p->user, 'Name', 'Update text', 'f', 'confirmed', 'confirmed');
    $c->discard_changes;
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

subtest 'Send comments' => sub {
  FixMyStreet::override_config {
    ALLOWED_COBRANDS => ['fixmystreet', 'bromley', 'buckinghamshire', 'oxfordshire'],
  }, sub {
    $o->send;
    $c3a->discard_changes;
    is $c3a->extra, undef, 'Bucks update by owner was sent';
    $c3b->discard_changes;
    is $c3b->send_state, 'skipped', 'Bucks update by other was not';
    $c1->discard_changes;
    is $c1->extra->{title}, "MRS", 'Title set on Bromley update';
    $c2->discard_changes;
    is $c2->send_fail_count, 1, 'Oxfordshire update skipped entirely, still logs as failure';
    $c2->update({ send_fail_count => 0 });

    Open311->_inject_response('/servicerequestupdates.xml', "", 500);
    $oxon_other->update({ email => 'Alloy-OTHER' });
    $o->send;
    $c2->discard_changes;
    my $p_id = $c2->problem->external_id;
    is $c2->send_fail_count, 1, 'Oxfordshire update attempted';
    like $c2->send_fail_reason, qr/service_request_id: $p_id/;
    $oxon_other->update({ email => 'OTHER' });
    $c2->update({ send_fail_count => 0 });

    Open311->_inject_response('/servicerequestupdates.xml', "", 500);
    $c2->problem->set_extra_metadata(customer_reference => 'ENQ12345');
    $c2->problem->update;
    $o->send;
    $c2->discard_changes;
    is $c2->send_fail_count, 1, 'Oxfordshire update attempted';
    like $c2->send_fail_reason, qr/service_request_id: ENQ12345/;
  };
};

subtest 'Processing things that do not need sending' => sub {
    my ($p1) = $mech->create_problems_for_body(1, $bromley->id, 'Title', { send_method_used => 'Email', whensent => \'current_timestamp', });
    my $c1 = c($p1);
    my ($p2) = $mech->create_problems_for_body(1, $bromley->id, 'Title', { send_method_used => 'Other', whensent => \'current_timestamp', external_id => 1 });
    my $c2 = c($p2);
    $o->send;
    $c1->discard_changes;
    $c2->discard_changes;
    is $c1->send_state, 'processed', 'Comment 1 marked as processed';
    is $c2->send_state, 'processed', 'Comment 2 marked as processed';
};

for my $test (
  ['Bexley', 'bexley', 2494],
  ['Hackney', 'hackney', 2508],
) {
  my ($name, $cobrand, $body_id) = @$test;

  subtest "Check $name munging" => sub {
    FixMyStreet::override_config {
      ALLOWED_COBRANDS => ['fixmystreet', $cobrand],
    }, sub {
      my $body = $mech->create_body_ok($body_id, $name, { %$params, cobrand => $cobrand });
      $mech->create_contact_ok(body_id => $body->id, category => 'Other', email => "OTHER");

      my $test_res = '<?xml version="1.0" encoding="utf-8"?><service_request_updates><request_update><update_id>248</update_id></request_update></service_request_updates>';
      my $o = Open311->new(
          fixmystreet_body => $body,
      );
      Open311->_inject_response('servicerequestupdates.xml', $test_res);
      my ($p5, $c5) = p_and_c($body);
      my $id = $o->post_service_request_update($c5);
      is $id, 248, 'correct update ID returned';
      like $o->test_req_used->content, qr/service_code=OTHER/, 'Service code included';
    };
  };
}

subtest 'Oxfordshire gets an ID' => sub {
  FixMyStreet::override_config {
    ALLOWED_COBRANDS => ['fixmystreet', 'bromley', 'buckinghamshire', 'oxfordshire'],
  }, sub {
    $p2->set_extra_metadata(customer_reference => 'ABC');
    $p2->update;
    $o->send;
    $c2->discard_changes;
    is $c2->send_fail_count, 1, 'Oxfordshire update tried to send, failed';
    stdout_like { $o->summary_failures } qr/The following updates failed sending/;
  };
};

subtest 'Devolved contact' => sub {
    $c1->update({ send_fail_count => 0 });
    Open311->_inject_response('/devolved-endpoint/servicerequestupdates.xml', "", 500);
    $o->send;
    $c1->discard_changes;
    like $c1->send_fail_reason, qr/devolved-endpoint/, 'Failure message contains correct endpoint';
};

done_testing();
