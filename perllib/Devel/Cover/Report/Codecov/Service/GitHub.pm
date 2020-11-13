package Devel::Cover::Report::Codecov::Service::GitHub;
use strict;
use warnings;
use utf8;

sub detect {
    return $ENV{GITHUB_ACTIONS};
}

sub configuration {
    (my $branch = $ENV{GITHUB_REF}) =~ s{^refs/heads/}{};

    my $conf = {
        service      => 'github-actions',
        commit       => $ENV{GITHUB_SHA},
        slug         => $ENV{GITHUB_REPOSITORY},
        build        => $ENV{GITHUB_RUN_ID},
        build_url    => "https://github.com/$ENV{GITHUB_REPOSITORY}/actions/runs/$ENV{GITHUB_RUN_ID}",
        branch       => $branch,
    };

    if ($ENV{GITHUB_HEAD_REF}) {
        (my $pr = $ENV{GITHUB_REF}) =~ s{^refs/pull/}{};
        $pr =~ s{/merge$}{};
        $conf->{pr} = $pr;
        $conf->{branch} = $ENV{GITHUB_HEAD_REF};
    }

    return $conf;
}

1;
__END__
