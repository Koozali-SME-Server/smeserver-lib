#----------------------------------------------------------------------
# Copyright 1999-2003 Mitel Networks Corporation
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#----------------------------------------------------------------------

package esmith::ConfigDB;

use strict;
use warnings;

use vars qw( $AUTOLOAD @ISA );

use esmith::DB::db;
@ISA = qw( esmith::DB::db );

use esmith::ConfigDB::Record;

=head1 NAME

esmith::ConfigDB - interface to esmith configuration database

=head1 SYNOPSIS

    use esmith::ConfigDB;
    my $db = esmith::ConfigDB->open;
    my $db = esmith::ConfigDB->open_ro;

    my @services = $db->services();

    # Singleton Records
    my $record = $db->get($key);
    my $value = $record->value;
    $record->set_value($value);

    # BAD!
    my $value = $db->get($key)->value() # Throws a runtime error if $key
                                        # doesn't exist
    $value = $db->get($key)->prop($p)   # Throws a runtime error if $key
                                        # doesn't exist

    # GOOD
    my $record = $db->get($key);
    my $value;
    if ($record)
    {
        $value = $record->prop($prop);
    }

    # Typed Records (eventually they all will be)
    my $prop = $record->prop($p);
    $record->set_prop($prop, $propvalue);
    my $value = $db->get_value($key)    # Returns undef if record doesn't exist
    $value = $db->get_prop($key, $p)    # Returns undef if record doesn't exist

=head1 DESCRIPTION

This module provides an abstracted interface to the esmith master
configuration database.

Unless otherwise noted, esmith::ConfigDB acts like esmith::DB::db.

=cut

our $VERSION = sprintf '%d.%03d', q$Revision: 1.29 $ =~ /: (\d+).(\d+)/;

=head2 open()

Like esmith::DB->open, but if given no $file it will try to open the
file in the ESMITH_CONFIG_DB environment variable or configuration.

=begin testing

use esmith::TestUtils qw(scratch_copy);
use_ok("esmith::ConfigDB");

my $scratch_copy_of_conf = scratch_copy('10e-smith-lib/configuration.conf');
$C = esmith::ConfigDB->open($scratch_copy_of_conf);
isa_ok($C, 'esmith::ConfigDB');
is( $C->get("AccessType")->prop('type'), "dedicated", 
                                    "We can get stuff from the db");

is( $C->get_prop("AccessType",'type'), "dedicated", 
                                    "We can get_prop stuff from the db");

is( $C->get_value("AccessType"), "dedicated", 
                                    "We can get_value stuff from the db");

is( $C->get_value("NoSuchKey"), undef, 
                                    "We can get_value non-existant keys");

is( $C->get_prop("diald","status"), "disabled", 
                                    "We can get_prop stuff from the db");

is( $C->get_prop("NoSuchKey","NoSuchProp"), undef, 
                                    "We can get_prop non-existant keys");

is( $C->get_prop("diald","NoSuchProp"), undef, 
                                    "We can get_prop non-existant props");

=end testing

=cut

sub open
{
    my ( $class, $file ) = @_;
    $file = $file || $ENV{ESMITH_CONFIG_DB} || "configuration";
    return $class->SUPER::open($file);
}

=head2 open_ro()

Like esmith::DB->open_ro, but if given no $file it will try to open the
file in the ESMITH_CONFIG_DB environment variable or configuration.

=begin testing

=end testing

=cut

sub open_ro
{
    my ( $class, $file ) = @_;
    $file = $file || $ENV{ESMITH_CONFIG_DB} || "configuration";
    return $class->SUPER::open_ro($file);
}

=head2 new_record()

This method creates a new record in the configuration database. As arguments,
it expects the key to the record, followed by a hash references with its
properties, including the type.

my $db = esmith::ConfigDB->open;
my $record = $db->new_record('zope', { type => 'service',
                                       status => 'disabled' });

my %defaults = qw(
    type => 'service',
    status => 'disabled',
    maintainer => 'admin@domain.com'
    );
my $record = $db->get('zope');
unless ($record)
{
    $record = $db->new_record('zope', \%defaults);
}

=head2 get()

Like their esmith::DB counterparts except they return
esmith::ConfigDB::Record objects which have a few extra methods.

my $record = $db->get('zope');

=begin testing

my $rec = eval { $C->get("I_dont_exist"); };
ok( !$rec, 'get() on a non-existent key' );
is( $@, '', '  doesnt blow up' );

isa_ok( $C->get("AccessType"), 'esmith::ConfigDB::Record', 
                                "get()ened records are ConfigDB::Records" );

$rec = $C->new_record("I_dont_exist", { type => "foo" });
isa_ok( $rec, 'esmith::ConfigDB::Record', 
                                "new_record()s are ConfigDB::Records" );
$rec->delete("I_dont_exist");
ok( !$C->get("I_dont_exist"), 'delete()' );

=end testing

=cut

sub get
{
    my ($self) = shift;

    my $rec = $self->SUPER::get(@_);
    return $rec ? bless $rec, 'esmith::ConfigDB::Record' : undef;
}

sub new_record
{
    my ($self) = shift;

    my $rec = $self->SUPER::new_record(@_);
    return $rec ? bless $rec, 'esmith::ConfigDB::Record' : undef;
}

=pod
 
=head2 getLocale()
 
Retrieves the locale and keyboard settings from the configuration database.
Returns ($lang, $kbdtype, $keytable) on success. Returns undef if the record
doesn't exist.
 
=cut

sub getLocale
{
    my $self     = shift;
    my $rec      = $self->get('sysconfig') or return undef;
    my $lang     = $rec->prop('Language') || 'en_US';
    my $kbdtype  = $rec->prop('KeyboardType') || 'pc';
    my $keytable = $rec->prop('Keytable') || 'us';
    return ( $lang, $kbdtype, $keytable );
}

=pod

=head2 hosts_allow_spec ($service [,$daemon])

Given a service, return the string suitable for /etc/hosts.allow,
checking to see if the service is defined, whether it is enabled and
whether access is set to public, private, or localhost.

An optional argument provides the tag which appears in hosts.allow. If not
given, the service name is used.

For example, one of the following:

# 'oidentd' is not defined in the configuration database
# 'oidentd' is disabled in the configuration database
in.identd: 127.0.0.1
in.identd: 127.0.0.1 192.168.1.1/255.255.255.0
in.identd: ALL

And here's the hosts.allow fragment:

{
    $OUT = $DB->hosts_allow_spec('oidentd', 'in.identd');
}

=cut

sub hosts_allow_spec
{
    my $self         = shift;
    my $service_name = shift;
    my $daemon       = shift || $service_name;

    my $service = $self->get($service_name)
      or return
      "# '$service_name' is not defined in the configuration database";

    my $status = $service->prop('status') || "disabled";
    return "# '$service_name' is disabled in the configuration database"
      unless ( $status eq "enabled" );

    my $access = $service->prop('access') || "private";

    use esmith::NetworksDB;
    my $ndb = esmith::NetworksDB->open_ro;

    my @spec = ( "$daemon:", $ndb->local_access_spec($access) );
    return "@spec";
}

=pod

=head2 wins_server

Return the value of the WINS server from the config db
or undef if we don't have a WINS server set and we are
not the domain master

=cut

sub wins_server
{
    my ($self) = @_;

    my $wins_server = $self->get_prop( 'smb', 'WINSServer' );

    return $wins_server if $wins_server;

    my $server_role = $self->get_prop( 'smb', 'ServerRole' ) || 'WS';

    return $self->get_prop( 'InternalInterface', 'IPAddress' )
      if $server_role =~ m{^(PDC|ADS)$};

    return undef;
}

=pod

=head2 services()

Returns a list of services in the configuration database

=for testing
foreach my $t (qw(services)) {
    my @list = $C->$t();
    ok(@list, "Got a list of $t");
}

=cut

sub AUTOLOAD
{
    my $self = shift;
    my ($called_sub_name) = ( $AUTOLOAD =~ m/([^:]*)$/ );
    my @types = qw( services );
    if ( grep /^$called_sub_name$/, @types )
    {
        $called_sub_name =~ s/s$//g;    # de-pluralize
        return $self->list_by_type($called_sub_name);
    }
}

=pod

=head2 _loadDefaults ($forceReset)

Behaves just like the esmith::DB method of the same name. This is a private
method used internally.

=begin testing

$scratch_copy_of_conf = scratch_copy('10e-smith-lib/configuration.conf', 'configuration.conf.scratch');
is ($scratch_copy_of_conf, 'configuration.conf.scratch', 'scratch copy name');
$ENV{'ESMITH_CONFIG_DB'} = $scratch_copy_of_conf;
$C = esmith::ConfigDB->open();
is ($C->{file}, $scratch_copy_of_conf, 'file name');
my $accesstype = $C->get("AccessType")->value;
ok($C->new_record('foobar', {type=>'service', status=>'disabled'}),
    "Set up foobar record");
is($C->get('foobar')->prop('status'), "disabled", "foobar is disabled");
$ENV{'ESMITH_DB_DEFAULTSDIR'} = "10e-smith-lib/db";
ok($C->_loadDefaults(), "Loaded defaults");
is($C->get('foobar')->prop('status'), 'enabled', "We forced status enabled");
is($C->get('bazbar')->prop('status'), 'enabled', "We included a new default");
is($C->get('AccessType')->value, $accesstype, "AccessType has not changed");

=end testing

=head2 record_has_defaults ($name)

Behaves just like the esmith::DB method of the same name.

=begin testing

$ENV{'ESMITH_DB_DEFAULTSDIR'} = "10e-smith-lib/db";
is($C->record_has_defaults('foobar'), 1, "foobar has some defaults");
is($C->record_has_defaults('notthisone'), undef, "notthisone does not");

=end testing

=cut

# There would normally be a method here, but we inherit _loadDefaults
# from esmith::DB. The tests need to go here because the superclass is
# all virtual and testing requires concrete open/get/set methods.

=pod

=head2 migrate

Just like the esmith::DB method of the same name.

=begin testing

$scratch_copy_of_conf = scratch_copy('10e-smith-lib/configuration.conf', 'configuration.conf.scratch');
is ($scratch_copy_of_conf, 'configuration.conf.scratch', 'scratch copy name');
$ENV{'ESMITH_CONFIG_DB'} = $scratch_copy_of_conf;
$C = esmith::ConfigDB->open();
is($C->get('quux'), undef, "No quux here");
$ENV{'ESMITH_DB_DEFAULTSDIR'} = "10e-smith-lib/db";
ok($C->migrate(), "We can migrate");
my $quux = $C->get('quux');
ok($quux, "We got quux");
is($quux->prop('status'), 'enabled', "We migrated to quux");
$quux->delete;

=end testing

=cut

# There would normally be a method here, but we inherit migrate
# from esmith::DB. The tests need to go here because the superclass is
# all virtual and testing requires concrete open/get/set methods.

=head1 AUTHOR

SME Server Developers <bugs@e-smith.com>

=head1 SEE ALSO

L<esmith::DB>, L<esmith::DB::db>, L<esmith::AccountsDB>, L<esmith::DomainsDB>,
L<esmith::HostsDB>, L<esmith::NetworksDB>, L<esmith::ConfigDB::Record>

=cut

1;
