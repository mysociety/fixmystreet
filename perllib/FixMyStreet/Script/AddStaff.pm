package FixMyStreet::Script::AddStaff;

use v5.14;
use warnings;

use Data::Dumper;
use Text::CSV qw ( csv );
use FixMyStreet::Cobrand;
use FixMyStreet::DB;
use mySociety::EmailUtil qw(is_valid_email);

sub run {
    my $opts = shift;

    my $commit = $opts->{commit};
    my $file = $opts->{staff};
    my $body_id = $opts->{body};

    if (!$opts->{commit}) {
        say "*** DRY RUN ***";
    }

    die "CSV file '$file' is empty or does not exist." unless -s $file;

    my $staff_to_add = csv (in => $file, headers => "auto") or
        die Text::CSV->error_diag;

    die "CSV has header row but no data." unless @$staff_to_add;

    my @headers = keys %{@{$staff_to_add}[0]};

    unless (grep(/^email$/, @headers)) {
        die "'email' column missing in CSV.";
    }

    unless (grep(/^name$/, @headers)) {
        die "'name' column missing in CSV.";
    }

    my $body = FixMyStreet::DB->resultset("Body")->find($body_id)
        or die "No body found with ID $body_id. Aborting.";

    my $users = FixMyStreet::DB->resultset("User");
    my $roles = FixMyStreet::DB->resultset("Role");

    my @plan;
    my $row = 0;
    foreach (@$staff_to_add) {
        $row++;

        my $email = $_->{email};
        my $name = $_->{name};
        my $role = $_->{role};
        my $area = $_->{area};

        say "\n$row: $email ($name)";

        unless (is_valid_email($email)) {
            die "Row $row has an invalid email: $email. Aborting.";
        }

        my $role_obj;
        if (defined $role && length $role) {
            $role_obj = $roles->find({ body_id => $body_id, name => $role })
                or die "Row $row has an invalid role for this body: $role. Aborting.";
        }

        my $area_id;
        if (defined $area && length $area) {
            my $children = $body->area_children || {};
            my ($child) = grep { $_->{name} eq $area } values %$children;
            $child or die "Row $row has an invalid area for this body: $area. Aborting.";
            $area_id = $child->{id};
        }

        my $user = $users->find({ email => $email });

        if ($user) {
            say "user already exists for $email";

            my $existing_name = $user->name;
            if ($existing_name ne $name) {
                die "Existing user's name ($existing_name) " .
                    "does not match the name given ($name). Aborting.";
            }

            my $existing_body = $user->from_body;
            if ($existing_body) {
                my $existing_body_id = $existing_body->id;
                if ($existing_body_id != $body_id) {
                    die "Existing user is staff for a different " .
                        "body ($existing_body_id). Aborting.";
                }
            }
        } else {
            $user = $users->new({ email => $email, email_verified => 1 });
        }

        my $action = $user->in_storage ? "Update" : "Create";
        say "$action user as staff for body $body_id"
            . ($role_obj ? ", role '$role'" : "")
            . (defined $area_id ? ", area $area" : "");

        push @plan, {
            user     => $user,
            name     => $name,
            role     => $role_obj,
            area_ids => defined $area_id ? [$area_id] : undef,
        };
    }

    return unless $commit;

    say "Committing changes...";

    foreach my $change (@plan) {
        my $user = $change->{user};
        $user->name($change->{name});
        $user->from_body($body_id);
        $user->area_ids($change->{area_ids}) if $change->{area_ids};
        $user->update_or_insert;

        if (my $role_obj = $change->{role}) {
            $user->add_to_roles($role_obj)
                unless $user->user_roles->search({ role_id => $role_obj->id })->count;
        }
    }

    say "Done!";
}

1;
