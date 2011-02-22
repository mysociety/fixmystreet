#!/bin/bash

# Set the Perl environment variables as needed
eval $(perl -Iperllib -Mlocal::lib=local-lib5)

# put a note in the promp so that we know environment is setup
PS1="(fms) $PS1"

