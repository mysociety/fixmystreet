#!/bin/bash

# Set the Perl environment variables as needed
eval $(perl -Iperllib -Mlocal::lib=local-lib5)

# add the non-standard perllib path to PERL5LIB
PERL5LIB=perllib:commonlib/perllib:$PERL5LIB

# put a note in the promp so that we know environment is setup
PS1="(fms) $PS1"

