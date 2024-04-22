use strict;
use warnings;

use FixMyStreet;
BEGIN { FixMyStreet->test_mode(1); }

package FixMyStreet::Cobrand::NoSizeLimit;
use parent 'FixMyStreet::Cobrand::Default';
use Moo;
with 'FixMyStreet::Roles::EnforcePhotoSizeOpen311PreSend';
sub per_photo_size_limit_for_report_in_bytes { 0 }

package FixMyStreet::Cobrand::SizeLimit;
use parent 'FixMyStreet::Cobrand::Default';
use Moo;
with 'FixMyStreet::Roles::EnforcePhotoSizeOpen311PreSend';
sub per_photo_size_limit_for_report_in_bytes { 100 }

package main;
use Test::MockModule;
use Test::More;
use FixMyStreet::Script::Reports;
use FixMyStreet::TestMech;

my $photoset = Test::MockModule->new('FixMyStreet::App::Model::PhotoSet');
my @shrink_all_to_size_arguments;

$photoset->mock('shrink_all_to_size', sub {
    my ($self, $size_bytes, $resize_percent) = @_;
    push @shrink_all_to_size_arguments, [$size_bytes, $resize_percent];
    return ($self, 1);
});

my $mech = FixMyStreet::TestMech->new;
my $mock_open311 = Test::MockModule->new('FixMyStreet::SendReport::Open311');

my $body = $mech->create_body_ok(1, 'Photo Enforce Size Limit Test Body', {
    endpoint => 'e',
    api_key => 'key',
    jurisdiction => 'j',
    send_method => 'Open311',
});

my $contact = $mech->create_contact_ok(
    body_id => $body->id,
    category => 'Photo Size Limit Enforced Category',
    email => '',
);

my $tag_name = 'photo_size_limit_applied_100';

FixMyStreet::override_config {
    ALLOWED_COBRANDS => ['nosizelimit', 'sizelimit'],
    STAGING_FLAGS => { send_reports => 1 },
}, sub {
    subtest 'Skips report if there are no photos' => sub {
        my ($report) = $mech->create_problems_for_body(1, $body->id, 'report', {
            cobrand => 'sizelimit',
            category => $contact->category,
            photo => undef,
        });
        FixMyStreet::Script::Reports::send();
        $report->discard_changes;
        is scalar @shrink_all_to_size_arguments, 0, "shrink_all_to_size shouldn't be called";
        is $report->get_extra_metadata($tag_name), undef, "tag shouldn't be set";
    };

    subtest 'Skips report if no limit is returned' => sub  {
        my ($report) = $mech->create_problems_for_body(1, $body->id, 'report', {
            cobrand => 'nosizelimit',
            category => $contact->category,
        });
        FixMyStreet::Script::Reports::send();
        $report->discard_changes;
        is scalar @shrink_all_to_size_arguments, 0, "shrink_all_to_size shouldn't be called";
        is $report->get_extra_metadata($tag_name), undef, "tag shouldn't be set";
    };

    subtest 'Skips report if tag says limit already applied' => sub  {
        my ($report) = $mech->create_problems_for_body(1, $body->id, 'report', {
            cobrand => 'sizelimit',
            category => $contact->category,
        });
        $report->set_extra_metadata($tag_name => 1);
        $report->update;
        FixMyStreet::Script::Reports::send();
        $report->discard_changes;
        is scalar @shrink_all_to_size_arguments, 0, "shrink_all_to_size shouldn't be called";
        is $report->get_extra_metadata($tag_name), 1, "tag shouldn't be cleared";
    };

    subtest 'Applies shrink and sets tag' => sub  {
        my ($report) = $mech->create_problems_for_body(1, $body->id, 'report', {
            cobrand => 'sizelimit',
            category => $contact->category,
        });
        FixMyStreet::Script::Reports::send();
        $report->discard_changes;
        is scalar @shrink_all_to_size_arguments, 1, "shrink_all_to_size should have been called";
        my ($size_limit, $percent) = @{$shrink_all_to_size_arguments[0]};
        is $size_limit, 100, "size limit should be 100 bytes";
        is $percent, 90, "resize percent  should be 90%";
        is $report->get_extra_metadata($tag_name), 1, "tag should be set";
    };
};

done_testing;
