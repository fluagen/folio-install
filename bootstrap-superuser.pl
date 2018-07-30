# Create a FOLIO "superuser" on a running system
# This assumes the Okapi API is not secured
# Modules required: mod-authtoken, mod-users, mod-login, mod-permissions, mod-users-bl
# 1. Disable mod-authtoken
# 2. Create records in mod-users, mod-login, mod-permissions
# 3. Re-enable mod-authtoken
# 4. Assign all permissions to the superuser

use strict;
use warnings;
use Getopt::Long;
use LWP;
use JSON;
use UUID::Tiny qw(:std);
use Data::Dumper;

$| = 1;
# Command line
my $tenant = 'diku';
my $user = 'diku_admin';
my $password = 'admin';
my $okapi = 'http://localhost:9130';
my $no_perms = '';
my $only_perms = '';
GetOptions( 'tenant|t=s' => \$tenant,
            'user|u=s' => \$user,
            'password|p=s' => \$password,
            'okapi=s' => \$okapi,
            'noperms' => \$no_perms,
            'onlyperms' => \$only_perms );

my $ua = LWP::UserAgent->new();

unless ($only_perms) {
  print "Disabling mod-authtoken...";
  my $header = [
                'Content-Type' => 'application/json',
                'Accept' => 'application/json, text/plain'
               ];
  my $req = HTTP::Request->new('POST',"$okapi/_/proxy/tenants/$tenant/install",$header,encode_json([ { id => 'mod-authtoken', action => 'disable' } ]));
  my $resp = $ua->request($req);
  die $resp->status_line . "\n" unless $resp->is_success;
  my $disabled = decode_json($resp->content);
  print "OK\n";
  print "Disabled:\n" . $resp->content . "\n";

  print "Creating user record...";
  my $user_id = create_uuid_as_string(UUID_V4);
  my $user = {
              id => $user_id,
              username => $user,
              active => \1,
              personal => { lastName => 'Superuser' }
             };
  $header = [
                'Content-Type' => 'application/json',
                'Accept' => 'application/json, text/plain',
                'X-Okapi-Tenant' => $tenant
               ];
  $req = HTTP::Request->new('POST',"$okapi/users",$header,encode_json($user));
  $resp = $ua->request($req);
  die $resp->status_line . "\n" unless $resp->is_success;
  print "OK\n";

  print "Creating login record...";
  my $login = {
               userId => $user_id,
               password => $password
              };
  $req = HTTP::Request->new('POST',"$okapi/authn/credentials",$header,encode_json($login));
  $resp = $ua->request($req);
  die $resp->status_line . "\n" unless $resp->is_success;
  print "OK\n";
  
  print "Creating permissions user record...";
  my $perms_user = {
                    userId => $user_id,
                    permissions => [ 'perms.all' ]
                   };
  $req = HTTP::Request->new('POST',"$okapi/perms/users",$header,encode_json($perms_user));
  $resp = $ua->request($req);
  die $resp->status_line . "\n" unless $resp->is_success;
  print "OK\n";

  print "Re-enabling mod-authtoken...";
  my $enable = [];
  foreach my $i (@{$disabled}) {
    $$i{action} = 'enable';
    push(@{$enable},$i);
  }
  $header = [
             'Content-Type' => 'application/json',
             'Accept' => 'application/json, text/plain'
            ];
  $req = HTTP::Request->new('POST',"$okapi/_/proxy/tenants/$tenant/install",$header,encode_json($enable));
  $resp = $ua->request($req);
  die $resp->status_line . "\n" unless $resp->is_success;
  print "OK\n";
}

unless ($no_perms) {
  print "Logging in superuser $user...";
  my $credentials = { username => $user, password => $password };
  my $header = [
                'Content-Type' => 'application/json',
                'Accept' => 'application/json, text/plain',
                'X-Okapi-Tenant' => $tenant
               ];
  my $req = HTTP::Request->new('POST',"$okapi/bl-users/login",$header,encode_json($credentials));
  my $resp = $ua->request($req);
  die $resp->status_line . "\n" unless $resp->is_success;
  my $login = decode_json($resp->content);
  my $perms_id = $$login{permissions}{id};
  my $token = $resp->header('X-Okapi-Token');
  print "OK\n";

  print "Getting list of permissions to assign...";
  $header = [
             'Accept' => 'application/json, text/plain',
             'X-Okapi-Tenant' => $tenant,
             'X-Okapi-Token' => $token
            ];
  $req = HTTP::Request->new('GET',"$okapi/perms/permissions?query=childOf%3D%3D%5B%5D&length=500",$header);
  $resp = $ua->request($req);
  die $resp->status_line . "\n" unless $resp->is_success;
  my $permissions = decode_json($resp->content);
  die "Retrieved permissions don't match total permissions count"
    unless @{$$permissions{permissions}} == $$permissions{totalRecords};
  print "OK\n";

  print "Assigning permissions...\n";
  foreach my $permission (@{$$permissions{permissions}}) {
    print "$$permission{permissionName}: ";
    my $assigned = 0;
    foreach my $assigned_perm (@{$$login{permissions}{permissions}}) {
      if ($assigned_perm eq $$permission{permissionName}) {
        print "OK (already assigned)\n";
        $assigned = 1;
        last;
      }
    }
    unless ($assigned) {
      $header = [
                 'Content-Type' => 'application/json',
                 'Accept' => 'application/json, text/plain',
                 'X-Okapi-Tenant' => $tenant,
                 'X-Okapi-Token' => $token
                ];
      my $perms_ref = { permissionName => $$permission{permissionName} };
      $req = HTTP::Request->new('POST',"$okapi/perms/users/$$login{permissions}{id}/permissions",$header,encode_json($perms_ref));
      $resp= $ua->request($req);
      if ($resp->is_success) {
        print "ASSIGNED\n";
      } else {
        warn "Can't grant permission $$permission{permissionName} to $user: " . $resp->status_line . "\n";
      }
    }
  }

  print "done!\n";
}

exit;
