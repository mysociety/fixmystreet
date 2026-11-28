package FixMyStreet::Script::RemoveStaff;

use v5.14;
use warnings;

use FixMyStreet::DB;

sub run {
    my $opts = shift;

    my $commit = $opts->{commit};
    my $file = $opts->{staff};
    my $body_id = $opts->{body};

    if (!$opts->{commit}) {
        say "*** DRY RUN ***";
    }

    die "Staff file '$file' is empty or does not exist." unless -s $file;

    open(my $fh, '<', $file) or die "Could not open '$file': $!";
    my @emails;
    while (my $line = <$fh>) {
        $line =~ s/^\s+//;
        $line =~ s/\s+$//;
        push @emails, $line if length $line;
    }
    close $fh;

    die "Staff file has no emails." unless @emails;

    my $body = FixMyStreet::DB->resultset("Body")->find($body_id)
        or die "No body found with ID $body_id. Aborting.";

    my $users = FixMyStreet::DB->resultset("User");

    my @plan;
    my $row = 0;
    foreach my $email (@emails) {
        $row++;

        say "\n$row: $email";

        my $user = $users->find({ email => $email })
            or die "Row $row has no user for email: $email. Aborting.";

        my $existing_body = $user->from_body;
        unless ($existing_body) {
            say "user is not staff for any body, skipping";
            next;
        }

        my $existing_body_id = $existing_body->id;
        if ($existing_body_id != $body_id) {
            die "User is staff for a different " .
                "body ($existing_body_id). Aborting.";
        }

        say "Remove staff status from $email";

        push @plan, $user;
    }

    return unless $commit;

    say "Committing changes...";

    foreach my $user (@plan) {
        $user->remove_staff;
        $user->update;
    }

    say "Done!";
}

1;
