package t::Mock::Static;

use Path::Tiny;
use Web::Simple;

my $sample_file = path(__FILE__)->parent->parent->child("app/controller/sample.jpg");
my $sample_photo = $sample_file->slurp_raw;

sub dispatch_request {
    my $self = shift;

    sub (GET + /image.jpeg) {
        my ($self) = @_;
        return [ 200, [ 'Content-Type' => 'image/jpeg' ], [ $sample_photo ] ];
    },
}

__PACKAGE__->run_if_script;
