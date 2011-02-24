use strict;
use warnings;

use Test::More;

use FixMyStreet;
use mySociety::Locale;

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

done_testing();
