use strict;
use warnings;

use Test::More;

use FixMyStreet;
use mySociety::Locale;
use Encode;
use Data::Dumper;
use Sort::Key qw(keysort);
use POSIX 'strcoll';
local $Data::Dumper::Sortkeys = 1;
use utf8;

# check that the mo files have been generated
die "You need to run 'commonlib/bin/gettext-makemo --quiet FixMyStreet' "
  . "to generate the *.mo files needed."
  unless -e FixMyStreet->path_to(
    'locale/cy_GB.UTF-8/LC_MESSAGES/FixMyStreet-EmptyHomes.mo');

# Example strings
my $english = "Sorry! Something's gone wrong.";
my $welsh   = "Ymddiheuriadau! Mae rhywbeth wedi mynd o'i le.";

# set english as the language
mySociety::Locale::negotiate_language(    #
    'en-gb,English,en_GB|cy,Cymraeg,cy_GB', 'en_GB'
);

mySociety::Locale::gettext_domain( 'FixMyStreet-EmptyHomes', 1 );
mySociety::Locale::change();
is _($english), $english, "english to english";

# set to welsh and check for translation
mySociety::Locale::change('cy');
is _($english), $welsh, "english to welsh";

# check that being in a deep directory does not confuse the code
chdir FixMyStreet->path_to('t/app/controller') . '';
mySociety::Locale::gettext_domain( 'FixMyStreet-EmptyHomes', 1,
    FixMyStreet->path_to('locale')->stringify );
mySociety::Locale::change('cy');
is _($english), $welsh, "english to welsh (deep directory)";

# test that sorting works as expected in the right circumstances...
my @random_sorted  = qw( Å Z Ø A );
my @EN_sorted      = qw( A Å Ø Z );
my @NO_sorted      = qw( A Z Ø Å );
my @default_sorted = qw( A Z Å Ø );

sub utf8_diag {
    diag encode_utf8( Dumper(@_) );
}

{

    mySociety::Locale::negotiate_language(    #
        'en-gb,English,en_GB|cy,Cymraeg,cy_GB', 'en_GB'
    );
    mySociety::Locale::change();

    no locale;

    is_deeply( [ sort @random_sorted ],
        \@default_sorted, "sort correctly with no locale" );

    is_deeply( [ keysort { $_ } @random_sorted ],
        \@default_sorted, "keysort correctly with no locale" );

    # Note - this obeys the locale
    is_deeply( [ sort { strcoll( $a, $b ) } @random_sorted ],
        \@EN_sorted, "sort strcoll correctly with no locale (to 'en_GB')" );
}

{
    mySociety::Locale::negotiate_language(    #
        'en-gb,English,en_GB|cy,Cymraeg,cy_GB', 'en_GB'
    );
    mySociety::Locale::change();
    use locale;

    is_deeply( [ sort @random_sorted ],
        \@EN_sorted, "sort correctly with use locale 'en_GB'" );

    # is_deeply( [ keysort { $_ } @random_sorted ],
    #     \@EN_sorted, "keysort correctly with use locale 'en_GB'" );

    is_deeply( [ sort { strcoll( $a, $b ) } @random_sorted ],
        \@EN_sorted, "sort strcoll correctly with use locale 'en_GB'" );
}

{
    mySociety::Locale::negotiate_language(    #
        'nb-no,Norwegian,nb_NO', 'nb_NO'
    );
    mySociety::Locale::change();
    use locale;

    is_deeply( [ sort @random_sorted ],
        \@NO_sorted, "sort correctly with use locale 'nb_NO'" );

    # is_deeply( [ keysort { $_ } @random_sorted ],
    #     \@NO_sorted, "keysort correctly with use locale 'nb_NO'" );

    is_deeply( [ sort { strcoll( $a, $b ) } @random_sorted ],
        \@NO_sorted, "sort strcoll correctly with use locale 'nb_NO'" );
}

done_testing();
