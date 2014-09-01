package Dataset::UK::Stats19::Cmd::Deploy;
use Moo;
use MooX::Cmd;
use Path::Tiny;
# use Archive::Any;
use feature 'say';

sub execute {
    my ($self, $args, $chain) = @_;
    my ($stats19) = @{ $chain };

    my $db = $stats19->db;

    $db->deploy;

    # my $result = $db->resultset('Accident')->first;
    # say Dumper({ $result->get_columns }); use Data::Dumper;
    # say $db->resultset('Accident')->count;
}

1;
