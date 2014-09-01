package Dataset::UK::Stats19::Cmd::Download;
use Moo;
use MooX::Cmd;
use LWP::Simple;
use Path::Tiny;
use feature 'say';

sub execute {
    my ($self, $args, $chain) = @_;
    my ($stats19) = @{ $chain };

    my $path = path( $stats19->data_directory, $stats19->zipfile )->stringify;
    my $result = getstore(
        $stats19->url,
        $path,
    );
    die $result unless $result == 200;

    say "Wrote to $path";
}

1;
