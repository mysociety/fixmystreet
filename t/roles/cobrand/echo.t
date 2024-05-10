use strict;
use warnings;

use FixMyStreet;
BEGIN { FixMyStreet->test_mode(1); }

package FixMyStreet::Cobrand::CobrandEchoTest;
use parent 'FixMyStreet::Cobrand::UKCouncils';

use Moo;
with 'FixMyStreet::Roles::Cobrand::Echo';

sub waste_bulky_missed_blocked_codes {}
sub waste_containers {}
sub waste_service_to_containers {}
sub waste_quantity_max {}
sub waste_extra_service_info {}

sub garden_subscription_event_id {}
sub garden_echo_container_name {}
sub garden_container_data_extract {}
sub garden_due_days {}
sub garden_service_id {}

package main;
use Test::More;
use FixMyStreet;
use FixMyStreet::TestMech;

my $mech = FixMyStreet::TestMech->new;
my $cobrand = FixMyStreet::Cobrand::CobrandEchoTest->new;
my $body = $mech->create_body_ok(1, 'body');
my $bulky_contact = $mech->create_contact_ok(
    body_id => $body->id,
    category => 'Bulky collection',
    email => '',
);
my $non_bulky_contact = $mech->create_contact_ok(
    body_id => $body->id,
    category => 'Non bulky',
    email => '',
);
my ($bulky_report) = $mech->create_problems_for_body(1, $body->id, 'report', {
    category => $bulky_contact->category,
    cobrand_data => 'waste',
});

FixMyStreet::override_config {
    COBRAND_FEATURES => {
        echo => {
            max_size_per_image_bytes => 100,
            max_size_image_total_bytes => 201,
        },
    },
}, sub {
    subtest 'Image size limit is applied correctly' => sub {
        subtest 'Image size calculate from config for bulky reports' => sub {
            is $cobrand->per_photo_size_limit_for_report_in_bytes($bulky_report, 1), 100;
            is $cobrand->per_photo_size_limit_for_report_in_bytes($bulky_report, 2), 100;
            is $cobrand->per_photo_size_limit_for_report_in_bytes($bulky_report, 4), 50;
        };

        subtest 'No size limit for non-bulky reports' => sub {
            my ($non_bulky_report) = $mech->create_problems_for_body(1, $body->id, 'report', {
                category => $non_bulky_contact->category,
                cobrand_data => 'waste',
            });
            is $cobrand->per_photo_size_limit_for_report_in_bytes($non_bulky_report, 1), 0;
        };
    };
};

done_testing;
