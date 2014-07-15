package Open311::Endpoint::Role::ConfigFile;
use Moo::Role;
use Path::Tiny 'path';
use Carp 'croak';
use YAML ();
use Types::Standard qw( Maybe Str );

has config_file => (
    is => 'ro',
    isa => Maybe[Str],
);

around BUILDARGS => sub {
    my $next = shift;
    my $class = shift;

    my %args = @_;
    if (my $config_file = $args{config_file}) {
        my $cfg = path($config_file);
        croak "$config_file is not a file" unless $cfg->is_file;

        my $config = YAML::LoadFile($cfg) or croak "Couldn't load config from $config_file";
        return $class->$next(%$config, %args);
    }
    else {
        return $class->$next(%args);
    }
};

1;
