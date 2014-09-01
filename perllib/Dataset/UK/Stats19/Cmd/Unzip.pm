package Dataset::UK::Stats19::Cmd::Unzip;
use Moo;
use MooX::Cmd;
use Path::Tiny;
# use Archive::Any;
use feature 'say';

sub execute {
    my ($self, $args, $chain) = @_;
    my ($stats19) = @{ $chain };

    chdir $stats19->data_directory;
    system 'unzip', $stats19->zipfile;
}

1;
