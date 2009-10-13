#!/usr/bin/perl -w
#
# Problem.t:
# Tests for the Problem functions
#
#  Copyright (c) 2009 UK Citizens Online Democracy. All rights reserved.
# Email: louise@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Problems.t,v 1.1 2009-10-13 09:25:56 louise Exp $
#

use strict;
use warnings; 
use Test::More tests => 6;
use Test::Exception; 

use FindBin;
use lib "$FindBin::Bin";
use lib "$FindBin::Bin/../perllib";
use lib "$FindBin::Bin/../../perllib";

use Problems;

sub test_update_user_notified_data_sharing() {

   my $update = {created => 1256947200};
   my $notification_start = 1256947201;
   my $accepted = Problems::update_user_notified_data_sharing($update, $notification_start);
   ok($accepted == 0, 'update_user_notified_data_sharing returns false for an update created before the notification started to be displayed');
   $notification_start = 1256947199;
   $accepted = Problems::update_user_notified_data_sharing($update, $notification_start);
   ok($accepted == 1, 'update_user_notified_data_sharing  returns true for a problem created after the notification started to be displayed');
   return 1;
}

sub test_user_notified_data_sharing() {

    my $problem = {time => 1256947200};
    my $notification_start = 1256947201;
    my $accepted = Problems::user_notified_data_sharing($problem, $notification_start);
    ok($accepted == 0, 'user_notified_data_sharing returns false for a problem created before the notification started to be displayed');
    $notification_start = 1256947199;
    $accepted = Problems::user_notified_data_sharing($problem, $notification_start);
    ok($accepted == 1, 'user_notified_data_sharing  returns true for a problem created after the notification started to be displayed');
    return 1;
}

ok(test_user_notified_data_sharing() == 1, 'Ran all tests for user_notified_data_sharing ');
ok(test_update_user_notified_data_sharing() == 1, 'Ran all tests for update_user_notified_data_sharing');

