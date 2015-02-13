use strict;

package PoChange;

sub translate($$) {
    my $file = shift;
    my $s = shift;

    if ( $file eq 'FixMyStreet-EmptyHomes' ) {
        return fixmystreet_to_reportemptyhomes( $s );
    } elsif ( $file eq 'FixMyBarangay' ) {
        return fixmystreet_to_fixmybarangay( $s );
    }

    return $s;
}

# Takes a msgid from the main FixMyStreet .po file and
# converts it to a msgid for the ReportEmptyHomes .po file
sub fixmystreet_to_reportemptyhomes($) {
    my $s = shift;

    $s =~ s/FixMyStreet/reportemptyhomes.com/g;
    $s =~ s/\bproblem\b/empty property/g;
    $s =~ s/\bProblem\b/Empty property/g;
    $s =~ s/\bproblems\b/empty properties/g;
    $s =~ s/\bProblems\b/Empty properties/g;
    $s =~ s/a empty/an empty/g;
    $s =~ s/fixed/returned to use/g;

    $s =~ s/Recently put back into use empty properties/Recent empty properties put back into use/;
    $s =~ s/New empty properties/New empty property reports/;
    $s =~ s/Older empty properties/Older empty property reports/;
    $s =~ s/Report, view, or discuss local empty properties/Report and view empty properties/;
    $s =~ s/There were empty properties with your/There were problems with your/;

    $s =~ s/\(like graffiti.*\)/ /;
    $s =~ s/(Please enter your full name).*? -/$1 -/;

    $s =~ s/We send it to the council on your behalf/The details will be sent directly to the right person in the local council for them to take action/;
    $s =~ s/To find out what local alerts we have for you/To find out what local alerts we have in your area, council or ward/;
    $s =~ s/Local alerts/Get local reports/;
    $s =~ s/Report an empty property/Report a property/;
    $s =~ s/Help/FAQs/;

    return $s;
}

sub fixmystreet_to_fixmybarangay($) {
    my $s = shift;

    $s =~ s/FixMyStreet/FixMyBarangay/g;
    $s =~ s/\bcouncil\b/barangay/g;
    $s =~ s/\bCouncil\b/Barangay/g;
    $s =~ s/\bcouncils\b/barangays/g;
    $s =~ s/\bCouncils\b/Barangays/g;

    return $s;
}

1;
