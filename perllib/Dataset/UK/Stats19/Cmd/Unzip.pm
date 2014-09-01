package Dataset::UK::Stats19::Cmd::Unzip;
use Moo;
use MooX::Cmd;
use Path::Tiny;
# use Archive::Any;
use feature 'say';

sub execute {
    my ($self, $args, $chain) = @_;
    my ($stats19) = @{ $chain };

    my $path = path( $stats19->data_directory, $stats19->zipfile )->stringify;

    system 'unzip', $path, '-e', $stats19->data_directory;

    # my $archive = Archive::Any->new( $path );
    # $archive->extract;
}

1;
