use FixMyStreet::TestMech;
use FixMyStreet::Script::RemoveStaff;
use FixMyStreet::DB;

use File::Temp;
use File::Spec;
use Path::Tiny;
use Test::Exception;
use Test::Output;

my $mech = FixMyStreet::TestMech->new();

my $aberdeenshire = $mech->create_body_ok(
    2648, 'Aberdeenshire Council',
    { cobrand => 'aberdeenshire'}
);
my $brent = $mech->create_body_ok(
    2488, 'Brent Council',
    { cobrand => 'brent'}
);

my $inspector_role = $brent->roles->create({
    name => 'Inspector',
    permissions => ['report_inspect'],
});

my $non_staff_user = $mech->create_user_ok(
    'non-staff-user@example.com',
    name => "Non Staff-User"
);
my $staff_wrong_body = $mech->create_user_ok(
    'staff-wrong-body@example.com',
    name => "Staff Wrong-Body",
    from_body => $aberdeenshire
);
my $staff_user = $mech->create_user_ok(
    'staff-user@example.com',
    name => "Staff User",
    from_body => $brent
);
$staff_user->add_to_roles($inspector_role);
$staff_user->area_ids([165138]);
$staff_user->update;

sub run {
    my ($filename, $commit) = @_;
    # Silence the script's progress output during tests.
    open(my $devnull, '>', File::Spec->devnull);
    local *STDOUT = $devnull;
    return FixMyStreet::Script::RemoveStaff::run({
        staff => $filename,
        commit => $commit,
        body => $brent->id
    });
}

subtest "errors on bad file" => sub {

    subtest "doesn't exist" => sub {
        throws_ok { run('doesnotexist.txt') } qr/empty or does not exist/;
    };

    subtest "no emails" => sub {
        my $fh = File::Temp->new;
        print $fh "\n  \n";
        close $fh;
        throws_ok { run($fh->filename) } qr/has no emails/;
    };

};

subtest "aborts on bad entries" => sub {

    subtest "no user for email" => sub {
        my $fh = File::Temp->new;
        print $fh <<~'END';
        nobody@example.com
        END
        close $fh;
        throws_ok { run($fh->filename) } qr/has no user for email/;
    };

    subtest "user is staff for a different body" => sub {
        my $email = $staff_wrong_body->email;
        my $fh = File::Temp->new;
        print $fh "$email\n";
        close $fh;
        throws_ok { run($fh->filename) } qr/staff for a different body/;
    };

};

subtest "succeeds on valid input" => sub {
    my $staff_email = $staff_user->email;
    my $non_staff_email = $non_staff_user->email;
    my $fh = File::Temp->new;
    print $fh <<~"END";
    $staff_email
    $non_staff_email
    END
    close $fh;

    my $users = FixMyStreet::DB->resultset("User");

    subtest "non-staff user is noted, not aborted on" => sub {
        lives_ok { run($fh->filename) };
    };

    subtest "dry run makes no changes" => sub {
        run($fh->filename);
        $staff_user->discard_changes;
        ok $staff_user->from_body, "staff user still has from_body after dry run";
    };

    subtest "commit removes staff status" => sub {
        run($fh->filename, 1);

        $staff_user->discard_changes;
        is $staff_user->from_body, undef, "from_body cleared";
        is $staff_user->area_ids, undef, "area_ids cleared";
        is_deeply [ $staff_user->roles->all ], [], "roles removed";

        $non_staff_user->discard_changes;
        is $non_staff_user->from_body, undef,
            "non-staff user left untouched";
    };
};

done_testing();
