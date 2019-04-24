# setenv script
requires 'List::MoreUtils', '0.402';
requires 'local::lib';
requires 'Class::Unload';

# Interesting installation issues, see end of this file
requires 'ExtUtils::MakeMaker', '6.72'; # [1]
# requires 'MooseX::NonMoose'; # [2]

# Minimum versions of dependencies to upgrade for bugfixes
requires 'Guard', '1.023';
requires 'PadWalker', '2.2';
requires 'aliased', '0.34';
requires 'Net::SSLeay', '1.81';
requires 'Module::ScanDeps', '1.24';
requires 'CGI', '4.38';
requires 'Lingua::EN::Tagger', '0.27';
requires 'Params::Classify', '0.014';

# Catalyst itself, and modules/plugins used
requires 'Catalyst', '5.80031';
requires 'Catalyst::Action::RenderView';
requires 'Catalyst::Authentication::Credential::MultiFactor';
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
requires 'Auth::GoogleAuth';
requires 'Authen::SASL';
requires 'Cache::Memcached';
requires 'Carp';
requires 'Crypt::Eksblowfish::Bcrypt';
requires 'Data::Password::Common';
requires 'DateTime';
requires 'DateTime::Format::HTTP';
requires 'DateTime::Format::ISO8601';
requires 'DateTime::Format::Pg';
requires 'DateTime::Format::W3CDTF';
requires 'DateTime::TimeZone', '2.18';
requires 'DBD::Pg', '2.9.2';
requires 'DBI';
requires 'DBIx::Class::EncodedColumn', '0.00013';
requires 'DBIx::Class::EncodedColumn::Crypt::Eksblowfish::Bcrypt';
requires 'DBIx::Class::Factory';
requires 'DBIx::Class::FilterColumn';
requires 'DBIx::Class::InflateColumn::DateTime';
requires 'DBIx::Class::ResultSet';
requires 'DBIx::Class::Schema::Loader';
requires 'Digest::MD5';
requires 'Digest::SHA';
requires 'Email::MIME';
requires 'Email::Sender';
requires 'Email::Valid';
requires 'Error';
requires 'FCGI'; # Required by e.g. Plack::Handler::FCGI
requires 'File::Find';
requires 'File::Path';
requires 'Geography::NationalGrid';
requires 'Getopt::Long::Descriptive';
requires 'HTML::Entities';
requires 'HTTP::Request::Common';
requires 'Image::Size';
requires 'IO::Socket::SSL', '2.007';
requires 'IO::String';
requires 'JSON::MaybeXS';
requires 'Locale::gettext';
requires 'LWP::Simple';
requires 'LWP::UserAgent';
requires 'Math::Trig';
requires 'MIME::Parser'; # HandleMail
requires 'Module::Pluggable';
requires 'Moose';
requires 'MooX::Types::MooseLike';
requires 'namespace::autoclean';
requires 'Net::Amazon::S3';
requires 'Net::DNS::Resolver';
requires 'Net::Domain::TLD', '1.75';
requires 'Net::Facebook::Oauth2', '0.11';
requires 'Net::OAuth';
requires 'Net::Twitter::Lite::WithAPIv1_1', '0.12008';
requires 'Number::Phone', '3.4003';
requires 'Path::Class';
requires 'POSIX';
requires 'Readonly';
requires 'Regexp::Common';
requires 'Scalar::Util';
requires 'Statistics::Distributions';
requires 'Storable';
requires 'Template::Plugin::Number::Format';
requires 'Text::CSV';
requires 'URI', '1.71';
requires 'URI::Escape';
requires 'URI::QueryParam';
requires 'WWW::Twilio::API';
requires 'XML::RSS';
requires 'XML::Simple';
requires 'YAML';

feature 'uk', 'FixMyStreet.com specific requirements' => sub {
    # East Hampshire
    requires 'SOAP::Lite', '1.20';
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
requires 'File::ChangeNotify';
requires 'Path::Tiny', '0.104';
requires 'File::Find::Rule';

# Modules used for development
requires 'Plack::Middleware::Debug';
requires 'Plack::Middleware::Debug::DBIC::QueryLog';
requires 'Plack::Middleware::Debug::LWP';
requires 'Plack::Middleware::Debug::Template';
recommends 'Linux::Inotify2' if $^O eq 'linux';
recommends 'Mac::FSEvents' if $^O eq 'darwin';

# Modules used by the test suite
requires 'Test::PostgreSQL', '1.25';
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
requires 'Test::WWW::Mechanize::Catalyst';
requires 'Web::Scraper';
requires 'Web::Simple';

#################################################################
#
# [1] Many things in cpanfile.snapshot require ExtUtils::MakeMaker 6.59, and
# one thing (DBIx::Class::IntrospectableM2M) requires 6.72, and so the snapshot
# contains the details for ExtUtils::MakeMaker 6.72. carton itself requires
# ExtUtils::MakeMaker 6.64.
#
# I don't understand the intracacies of carton/cpanm, but from the
# build.logs, I ascertain that DBIx::Class::Schema::Loader requires
# DBIx::Class::IntrospectableM2M and somehow in the process sets it up so that
# DBIx::Class::IntrospectableM2M tries to install the version of
# ExtUtils::MakeMaker used during the DBIx::Class::Schema::Loader installation.
#
# It seems as if the version of ExtUtils::MakeMaker used at any point is the
# one in local if present, then the one in local-carton if present, then the
# system one. Let's look at a few different installation platforms:
#
# On Debian wheezy, ExtUtils::MakeMaker is version 6.57. The installation of
# carton installs ExtUtils::MakeMaker 7.04 in local-carton. Running carton
# install installs ExtUtils::MakeMaker 6.72 in local at some point before
# DBIx::Class::Schema::Loader (due to one of the 6.59 requirements), and so
# DBIx::Class::IntrospectableM2M uses and tries to install 6.72, which is fine.
#
# On Ubuntu trusty, ExtUtils::MakeMaker is version 6.66. The installation of
# carton is satisfied already. Running carton install, nothing else upgrades
# ExtUtils::MakeMaker (as 6.66 > 6.59), and so when we get to
# DBIx::Class::IntrospectableM2M it uses the system 6.66 and upgrades to 6.72,
# which is again fine.
#
# On Mac OS X 10.9.5, ExtUtils::MakeMaker is version 6.63. The installation of
# carton installs ExtUtils::MakeMaker 7.04 in local-carton. Running carton
# install, nothing else upgrades ExtUtils::MakeMaker (as 6.63 > 6.59), and when
# we get to DBIx::Class::IntrospectableM2M it therefore uses 7.04 and can't
# install it (as the snapshot only contains 6.72) and fails.
#
# Therefore, if we make sure the ExtUtils::MakeMaker from the snapshot is
# installed early in the process, it will be available when we get to
# DBIx::Class::IntrospectableM2M, be used and match its own condition.
# I'm sure this isn't the correct solution, but it is a working one.
#
#
# [2] The installation of Catalyst::Model::DBIC::Schema tries to install any
# module that it finds already present in an optional section. On a Mac, the
# system has MooseX::NonMoose version 0.22, which is an optional component for
# Catalyst::Helper support, and it finds that but then thinks it is not
# installed, tries to install it but doesn't find it in the snapshot, and
# fails. The easiest solution here is to include MooseX::NonMoose in
# cpanfile.snapshot so it can be found, though I guess it shouldn't be trying
# to install it if it's already thought that 0.22 was installed...
