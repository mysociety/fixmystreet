use FixMyStreet::TestMech;
use Test::LongString;
use Test::Exception;
use Test::Output;
use Path::Tiny;

use_ok 'FixMyStreet::Script::ExportImport';

my $mech = FixMyStreet::TestMech->new;

my $name = 'Gloucestershire County Council';
my $body = $mech->create_body_ok(2226, $name);

my $pothole = $mech->create_contact_ok(body => $body, category => 'Pothole', email => 'pothole@example.org');
$mech->create_contact_ok(body => $body, category => 'Street light', email => 'light@example.org');
$mech->create_contact_ok(body => $body, category => 'Trees', email => 'trees@example.org');

my $user = $mech->create_user_ok('staff@example.org', from_body => $body, name => 'Staff User');
my $role = FixMyStreet::DB->resultset("Role")->create({ body => $body, name => "Admin" });
$user->add_to_roles($role);

my $template = FixMyStreet::DB->resultset("ResponseTemplate")->create({ body => $body, title => 'Ack', text => 'Ack' });

my $pothole_output = <<'EOF';
      {
         "category" : "Pothole",
         "email" : "pothole@example.org",
         "extra" : null,
         "non_public" : false,
         "send_method" : "",
         "state" : "confirmed"
      },
EOF
my $light_output = <<'EOF';
      {
         "category" : "Street light",
         "email" : "light@example.org",
         "extra" : null,
         "non_public" : false,
         "send_method" : "",
         "state" : "confirmed"
      },
EOF
my $tree_output = <<'EOF';
      {
         "category" : "Trees",
         "email" : "trees@example.org",
         "extra" : null,
         "non_public" : false,
         "send_method" : "",
         "state" : "confirmed"
      }
EOF
my $role_output = <<'EOF';
   "roles" : [
      {
         "name" : "Admin",
         "permissions" : null
      }
   ],
EOF
my $template_output = <<'EOF';
   "templates" : [
      {
         "auto_response" : 0,
         "categories" : [],
         "email_text" : null,
         "external_status_code" : null,
         "state" : null,
         "text" : "Ack",
         "title" : "Ack"
      }
   ],
EOF
my $user_output = <<'EOF';
   "users" : [
      {
         "areas" : [],
         "categories" : [],
         "email" : "pkg-tscriptexportimportt-staff@example.org",
         "name" : "Staff User",
         "password" : "",
         "roles" : [
            "Admin"
         ]
      }
   ]
EOF
my $standard_output = "$role_output$template_output$user_output";

my $process = FixMyStreet::Script::ExportImport->new({
    body => $name,
    commit => 1,
});

subtest 'Exporting' => sub {
    my $out = $process->export_json([], 0);
    is_string $out, "{\n$standard_output}\n";
    throws_ok { $process->export_json(['Flytipping'], 0); } qr/Categories mismatch/, 'Threw correct error';
    $out = $process->export_json(['Pothole', 'Trees'], 0);
    # No templates specifically in those categories
    is_string $out, <<EOF;
{\n   "contacts" : [\n$pothole_output$tree_output   ],\n$role_output$user_output}
EOF
    $out = $process->export_json([], 1);
    is_string $out, <<EOF;
{\n   "contacts" : [\n$pothole_output$light_output$tree_output   ],\n$standard_output}
EOF
};

subtest 'Importing' => sub {
    my $file = path(__FILE__)->parent(2)->child('fixtures/import.json');

    stderr_is { $process->import_json($file, 0, 0) } <<'EOF';
Category Pothole already exists, skipping
Template with title Ack already exists, skipping
Role Admin already exists; skipping
EOF
    isnt +FixMyStreet::DB->resultset("Contact")->find({ category => "Flytipping" }), undef;
    isnt +FixMyStreet::DB->resultset("Role")->find({ name => "Nothing much" }), undef;
    isnt +FixMyStreet::DB->resultset("ResponseTemplate")->find({ title => "Fixed" }), undef;
    isnt +FixMyStreet::DB->resultset("User")->find({ name => "Admin User" }), undef;

    stderr_is { $process->import_json($file, 1, 1) } <<'EOF';
Role Admin already exists; skipping
Role Nothing much already exists; skipping
User admin@example.org already exists; skipping
EOF
    $pothole->discard_changes;
    is $pothole->email, 'newpothole@example.org';
    $template->discard_changes;
    is $template->state, 'in progress';
};

done_testing;
