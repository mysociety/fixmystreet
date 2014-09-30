#!/bin/bash

# abort on any errors
set -e

# check that we are in the expected directory
cd `dirname $0`/..

# install sass locally
mkdir -p "../gems"
export GEM_HOME="$(cd ../gems && pwd -P)"
echo $GEM_HOME
export PATH="$GEM_HOME/bin:$PATH"

if [ ! -f ../gems/bin/sass ]; then
    gem install --no-ri --no-rdoc sass    # -v 3.2.14
fi

if [ ! -f ../gems/bin/compass ]; then
   gem install --no-ri --no-rdoc compass # -v 0.12.2
fi

bin/make_css $*
