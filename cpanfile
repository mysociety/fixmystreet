# setenv script
requires 'List::MoreUtils', '0.402';
requires 'local::lib', '2.000024';
requires 'Class::Unload';

# Interesting installation issues, see end of this file
requires 'ExtUtils::MakeMaker', '7.20';
requires 'ExtUtils::ParseXS', '3.30'; # [1]
# requires 'MooseX::NonMoose'; # [2]

# Minimum versions of dependencies to upgrade for bugfixes
requires 'CGI', '4.43';
requires 'Net::Server', '2.009';
# For perl 5.20/5.22 support
  requires 'Guard', '1.023';
  requires 'PadWalker', '2.2';
  requires 'aliased', '0.34';
# For perl 5.24 support
  requires 'Net::SSLeay', '1.85';
# Issues to do with things already installed on Travis
  requires 'Module::ScanDeps', '1.24';
  requires 'Class::Load', '0.25';
# For perl 5.26/5.28 support
  requires 'Lingua::EN::Tagger', '0.27';
  requires 'Params::Classify', '0.014';
# To remove deprecated Class::MOP calls
  requires 'Catalyst::Model::DBIC::Schema', '0.65';
  requires 'MooseX::Role::Parameterised', '1.10';
  requires 'CatalystX::Component::Traits', '0.19';
  requires 'MooseX::Traits::Pluggable', '0.12';

# Catalyst itself, and modules/plugins used
requires 'Catalyst', '5.90124';
requires 'Catalyst::Action::RenderView';
requires 'Catalyst::Authentication::Credential::MultiFactor';
requires 'Catalyst::Authentication::Store::DBIx::Class';
requires 'Catalyst::Devel';
requires 'Catalyst::DispatchType::Regex', '5.90035';
requires 'Catalyst::Model::Adaptor';
requires 'Catalyst::Plugin::Authentication';
requires 'Catalyst::Plugin::Session::State::Cookie';
requires 'Catalyst::Plugin::Session::Store::DBIC';
requires 'Catalyst::Plugin::SmartURI', '0.041';
requires 'Catalyst::Plugin::Static::Simple', '0.36';
requires 'Catalyst::View::TT';
requires 'URI::SmartURI';

# Modules used by FixMyStreet
requires 'Auth::GoogleAuth';
requires 'Authen::SASL';
requires 'Cache::Memcached';
requires 'Carp';
requires 'Crypt::Eksblowfish::Bcrypt';
requires 'Data::Password::Common';
requires 'DateTime', '1.51';
requires 'DateTime::Format::Flexible';
requires 'DateTime::Format::HTTP';
requires 'DateTime::Format::ISO8601';
requires 'DateTime::Format::Pg';
requires 'DateTime::Format::Strptime';
requires 'DateTime::Format::W3CDTF';
requires 'DateTime::TimeZone', '2.35';
requires 'DBD::Pg', '3.8.0';
requires 'DBI';
requires 'DBIx::Class', '0.082841';
requires 'DBIx::Class::EncodedColumn', '0.00015';
requires 'DBIx::Class::EncodedColumn::Crypt::Eksblowfish::Bcrypt';
requires 'DBIx::Class::Factory';
requires 'DBIx::Class::FilterColumn';
requires 'DBIx::Class::InflateColumn::DateTime';
requires 'DBIx::Class::ResultSet';
requires 'DBIx::Class::Schema::Loader';
requires 'Digest::MD5';
requires 'Digest::SHA';
requires 'Email::Address', '1.912';
requires 'Email::MIME', '1.946';
requires 'Email::Sender';
requires 'Email::Valid';
requires 'Error';
requires 'FCGI'; # Required by e.g. Plack::Handler::FCGI
requires 'File::Find';
requires 'File::Path';
requires 'Geography::NationalGrid',
    mirror => 'https://cpan.metacpan.org/';
requires 'Getopt::Long::Descriptive', '0.105';
requires 'HTML::Entities';
requires 'HTML::FormHandler::Model::DBIC';
requires 'HTML::Scrubber';
requires 'HTTP::Request::Common';
requires 'Image::Size', '3.300';
requires 'Image::PNG::QRCode';
requires 'IO::Socket::SSL', '2.066';
requires 'IO::String';
requires 'JSON::MaybeXS';
requires 'Locale::gettext';
requires 'LWP::Simple';
requires 'LWP::UserAgent';
requires 'Math::Trig';
requires 'MIME::Parser'; # HandleMail
requires 'Module::Pluggable';
requires 'Moose', '2.2011';
requires 'Moo', '2.003004';
requires 'MooX::Types::MooseLike';
requires 'namespace::autoclean', '0.28';
requires 'Net::Amazon::S3';
requires 'Net::DNS::Resolver';
requires 'Net::Domain::TLD', '1.75';
requires 'Net::Facebook::Oauth2', '0.11';
requires 'Net::OAuth';
requires 'Net::Twitter::Lite::WithAPIv1_1', '0.12008';
requires 'Number::Phone', '3.5000';
requires 'OIDC::Lite';
requires 'Parallel::ForkManager';
requires 'Path::Class';
requires 'POSIX';
requires 'Readonly';
requires 'Regexp::Common';
requires 'Scalar::Util';
requires 'Statistics::Distributions';
requires 'Starman', '0.4014';
requires 'Storable';
requires 'Template', '2.29';
requires 'Template::Plugin::Number::Format';
requires 'Text::CSV', '1.99';
requires 'URI', '1.71';
requires 'URI::Escape';
requires 'URI::QueryParam';
requires 'WWW::Twilio::API';
requires 'XML::RSS';
requires 'XML::Simple';
requires 'YAML', '1.28';

feature 'uk', 'FixMyStreet.com specific requirements' => sub {
    # East Hampshire
    requires 'SOAP::Lite', '1.20';
    # TfL
    requires 'Net::Subnet';
};

feature 'zurich', 'Zueri wie neu specific requirements' => sub {
    # Geocoder
    requires 'SOAP::Lite', '1.20';
};

feature 'kiitc', 'KiitC specific requirements' => sub {
    requires 'Spreadsheet::Read';
    requires 'Spreadsheet::ParseExcel';
    requires 'Spreadsheet::ParseXLSX';
};

# Moderation by from_body user
requires 'Algorithm::Diff';

# Modules used by CSS & watcher
requires 'CSS::Sass';
requires 'File::ChangeNotify', '0.31';
requires 'Path::Tiny', '0.104';
requires 'File::Find::Rule';

# Modules used for development
requires 'Plack', '1.0047';
requires 'Plack::Middleware::Debug';
requires 'Plack::Middleware::Debug::DBIC::QueryLog';
requires 'Plack::Middleware::Debug::LWP';
requires 'Plack::Middleware::Debug::Template';
recommends 'Linux::Inotify2' if $^O eq 'linux';
recommends 'Mac::FSEvents' if $^O eq 'darwin';

# Modules used by the test suite
requires 'Test::PostgreSQL', '1.27';
requires 'CGI::Simple';
requires 'HTTP::Headers';
requires 'HTTP::Response';
requires 'LWP::Protocol::PSGI';
requires 'Sort::Key';
requires 'Sub::Override';
requires 'Test::Exception';
requires 'Test::LongString';
requires 'Test::MockTime';
requires 'Test::More', '0.88';
requires 'Test::Output';
requires 'Test::Warn';
requires 'Test::WWW::Mechanize::Catalyst', '0.62';
requires 'Web::Scraper';
requires 'Web::Simple';

#################################################################
# [1] Params::Classify 0.13 installs XS, but 0.15 will only do so
# if ParseXS >= 3.30 is installed. If we don't do that, and are
# upgrading, it will error because both 0.13 and 0.15 get installed.
#
# [2] The installation of Catalyst::Model::DBIC::Schema tries to install any
# module that it finds already present in an optional section. On a Mac, the
# system has MooseX::NonMoose version 0.22, which is an optional component for
# Catalyst::Helper support, and it finds that but then thinks it is not
# installed, tries to install it but doesn't find it in the snapshot, and
# fails. The easiest solution here is to include MooseX::NonMoose in
# cpanfile.snapshot so it can be found, though I guess it shouldn't be trying
# to install it if it's already thought that 0.22 was installed...
