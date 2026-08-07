use FixMyStreet::TestMech;
use FixMyStreet::Script::AddStaff;
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

my $non_staff_user = $mech->create_user_ok(
    'non-staff-user@example.com',
    name => "Non Staff-User"
);
my $staff_wrong_body = $mech->create_user_ok(
    'staff-wrong-body@example.com',
    name => "Staff Wrong-Body",
    from_body => $aberdeenshire
);

my $inspector_role = $brent->roles->create({
    name => 'Inspector',
    permissions => ['report_inspect'],
});

sub run {
    my ($filename, $commit) = @_;
    # Silence the script's progress output during tests.
    open(my $devnull, '>', File::Spec->devnull);
    local *STDOUT = $devnull;
    return FixMyStreet::Script::AddStaff::run({
        staff => $filename,
        commit => $commit,
        body => $brent->id
    });
}

subtest "errors on bad CSV" => sub {

    subtest "doesn't exist" => sub {
        throws_ok { run('doesnotexist.csv') } qr/empty or does not exist/;
    };

    subtest "header only" => sub {
        my $fh = File::Temp->new;
        print $fh <<~'END';
        email,name
        END
        close $fh;
        throws_ok { run($fh->filename) } qr/has header row but no data/;
    };

    subtest "missing 'email' field" => sub {
        my $fh = File::Temp->new;
        print $fh <<~'END';
        not_email,name
        email@example.com,bob
        END
        close $fh;
        throws_ok { run($fh->filename) } qr/'email' column missing/;
    };

    subtest "missing 'name' field" => sub {
        my $fh = File::Temp->new;
        print $fh <<~'END';
        email,not_name
        email@example.com,bob
        END
        close $fh;
        throws_ok { run($fh->filename) } qr/'name' column missing/;
    };

};

subtest "aborts on bad entries" => sub {

    subtest "invalid email" => sub {
        my $fh = File::Temp->new;
        print $fh <<~'END';
        email,name
        notanemail,Exists Non-Staff
        END
        close $fh;
        throws_ok { run($fh->filename) } qr/Row 1 has an invalid email/;
    };

    subtest "invalid role" => sub {
        my $fh = File::Temp->new;
        print $fh <<~'END';
        email,name,role
        new-role-user@example.com,New Role-User,Nonexistent
        END
        close $fh;
        throws_ok { run($fh->filename) } qr/invalid role/;
    };

    subtest "invalid area" => sub {
        my $fh = File::Temp->new;
        print $fh <<~'END';
        email,name,area
        new-area-user@example.com,New Area-User,Nonexistent
        END
        close $fh;
        FixMyStreet::override_config {
            MAPIT_URL => 'http://mapit.uk/',
            ALLOWED_COBRANDS => [ 'brent' ],
        }, sub {
            throws_ok { run($fh->filename) } qr/invalid area/;
        };
    };

    subtest "user exists but name doesn't match" => sub {
        my $email = $non_staff_user->email;
        my $fh = File::Temp->new;
        print $fh <<~"END";
        email,name
        $email,bob
        END
        close $fh;
        throws_ok { run($fh->filename) } qr/does not match the name given/;
    };

    subtest "user exists and belongs to a different body" => sub {
        my $email = $staff_wrong_body->email;
        my $name = $staff_wrong_body->name;
        my $fh = File::Temp->new;
        print $fh <<~"END";
        email,name
        $email,$name
        END
        close $fh;
        throws_ok { run($fh->filename) } qr/staff for a different body/;
    };

};

subtest "succeeds on valid input" => sub {
    my $new_user_email = 'new-staff@example.com';
    my $new_user_name = 'New Staff-User';
    my $existing_user_email = $non_staff_user->email;
    my $existing_user_name = $non_staff_user->name;
    my $fh = File::Temp->new;
    print $fh <<~"END";
    email,name,role,area
    $new_user_email,$new_user_name,Inspector,Alperton
    $existing_user_email,$existing_user_name,Inspector,Alperton
    END
    close $fh;

    my $users = FixMyStreet::DB->resultset("User");

    subtest "dry run makes no changes" => sub {
        FixMyStreet::override_config {
            MAPIT_URL => 'http://mapit.uk/',
            ALLOWED_COBRANDS => [ 'brent' ],
        }, sub {
            run($fh->filename);
        };
        is $users->find({ email => $new_user_email }), undef,
            "new user not created during dry run";
    };

    subtest "commit creates and configures the users" => sub {
        FixMyStreet::override_config {
            MAPIT_URL => 'http://mapit.uk/',
            ALLOWED_COBRANDS => [ 'brent' ],
        }, sub {
            run($fh->filename, 1);
        };
        my $new_user = $users->find({ email => $new_user_email });
        ok $new_user, "user created";
        is $new_user->name, $new_user_name, "name set";
        is $new_user->from_body->id, $brent->id, "from_body set to target body";
        is_deeply $new_user->area_ids, [165138], "area_ids set to given area";
        is_deeply [ map { $_->name } $new_user->roles->all ], ['Inspector'],
            "given role assigned";

        my $existing_user = $users->find({ email => $existing_user_email });
        is $existing_user->from_body->id, $brent->id, "from_body set to target body";
        is_deeply $existing_user->area_ids, [165138], "area_ids set to given area";
        is_deeply [ map { $_->name } $existing_user->roles->all ], ['Inspector'],
            "given role assigned";
    };
};

done_testing();
