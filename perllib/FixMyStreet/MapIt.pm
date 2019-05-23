package FixMyStreet::MapIt;

use FixMyStreet;
use mySociety::MaPit;

sub call {
    my ($url, $params, %opts) = @_;

    # 'area' always returns the ID you provide, no matter its generation, so no
    # point in specifying it for that. 'areas' similarly if given IDs, but we
    # might be looking up types or names, so might as well specify it then.
    $opts{generation} = FixMyStreet->config('MAPIT_GENERATION')
        if !$opts{generation} && $url ne 'area' && FixMyStreet->config('MAPIT_GENERATION');

    return mySociety::MaPit::call($url, $params, %opts);
}

1;
