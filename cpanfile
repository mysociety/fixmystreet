# setenv script
requires 'List::MoreUtils';
requires 'local::lib';
requires 'Class::Unload';

# Catalyst itself, and modules/plugins used
requires 'Catalyst', '5.80031';
requires 'Catalyst::Action::RenderView';
requires 'Catalyst::Authentication::Store::DBIx::Class';
requires 'Catalyst::Devel';
requires 'Catalyst::Model::Adaptor';
requires 'Catalyst::Plugin::Authentication';
requires 'Catalyst::Plugin::Session::State::Cookie';
requires 'Catalyst::Plugin::Session::Store::DBIC';
requires 'Catalyst::Plugin::SmartURI';
requires 'Catalyst::Plugin::Static::Simple';
requires 'Catalyst::Plugin::Unicode::Encoding';
requires 'Catalyst::View::TT';

# Modules used by FixMyStreet
requires 'Authen::SASL';
requires 'Cache::Memcached';
requires 'Carp';
requires 'CGI';
requires 'Crypt::Eksblowfish::Bcrypt';
requires 'DateTime';
requires 'DateTime::Format::HTTP';
requires 'DateTime::Format::ISO8601';
requires 'DateTime::Format::Pg';
requires 'DateTime::Format::W3CDTF';
requires 'DateTime::TimeZone';
requires 'DBD::Pg', '2.9.2';
requires 'DBI';
requires 'DBIx::Class::EncodedColumn::Crypt::Eksblowfish::Bcrypt';
requires 'DBIx::Class::FilterColumn';
requires 'DBIx::Class::InflateColumn::DateTime';
requires 'DBIx::Class::ResultSet';
requires 'DBIx::Class::Schema::Loader';
requires 'Digest::MD5';
requires 'Digest::SHA';
requires 'Email::Send';
requires 'Email::Send::SMTP';
requires 'Email::Simple';
requires 'Email::Valid';
requires 'Error';
requires 'FCGI';
requires 'File::Find';
requires 'File::Path';
requires 'File::Slurp';
requires 'Geography::NationalGrid';
requires 'Getopt::Long::Descriptive';
requires 'HTML::Entities';
requires 'HTTP::Request::Common';
requires 'Image::Size';
requires 'IO::String';
requires 'JSON';
requires 'JSON::XS';
requires 'LWP::Simple';
requires 'LWP::UserAgent';
requires 'Math::Trig';
requires 'Module::Pluggable';
requires 'Moose';
requires 'namespace::autoclean';
requires 'Net::Domain::TLD';
requires 'Net::SMTP::SSL';
requires 'Net::SMTP::TLS';
requires 'Path::Class';
requires 'POSIX';
requires 'Readonly';
requires 'Regexp::Common';
requires 'Scalar::Util';
requires 'Statistics::Distributions';
requires 'Storable';
requires 'Template::Plugin::Comma';
requires 'Text::CSV';
requires 'URI';
requires 'URI::Escape';
requires 'URI::QueryParam';
requires 'XML::RSS';
requires 'XML::Simple';
requires 'YAML';

feature 'uk', 'FixMyStreet.com specific requirements' => sub {
    # East Hampshire
    requires 'SOAP::Lite';
    # Barnet
    # TODO: This can perhaps be removed since Barnet switched to email for problem reports
    requires 'SOAP::WSDL';
};

feature 'open311-endpoint', 'Open311::Endpoint specific requirements' => sub {
    requires 'Web::Simple';
    requires 'Data::Rx';
    requires 'MooX::HandlesVia';
    requires 'Types::Standard';
    requires 'LWP::Protocol::PSGI'; # for testing end-to-end
    requires 'DateTime::Format::Oracle'; # for EXOR
};

feature 'zurich', 'Zueri wie neu specific requirements' => sub {
#    # Geocoder
    requires 'SOAP::Lite';
};

# Moderation by from_body user
requires 'Algorithm::Diff';

# Modules used by css watcher
requires 'File::ChangeNotify';
requires 'Path::Tiny';
requires 'File::Find::Rule';

feature 'run-tests', 'Spin up a test database and config to run tests' => sub {
    requires 'Test::PostgreSQL';
};

# Modules used by the test suite
requires 'CGI::Simple';
requires 'HTTP::Headers';
requires 'HTTP::Response';
requires 'Sort::Key';
requires 'Sub::Override';
requires 'Test::Exception';
requires 'Test::LongString';
requires 'Test::MockTime';
requires 'Test::More', '0.88';
requires 'Test::Warn';
requires 'Test::WWW::Mechanize::Catalyst';
requires 'Web::Scraper';

