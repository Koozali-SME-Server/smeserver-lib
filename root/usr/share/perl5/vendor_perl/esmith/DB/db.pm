#----------------------------------------------------------------------
# Copyright 1999-2003 Mitel Networks Corporation
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#----------------------------------------------------------------------

package esmith::DB::db;

use strict;
use warnings;
use Carp;

our $VERSION = sprintf '%d.%03d', q$Revision: 1.29 $ =~ /: (\d+).(\d+)/;

use esmith::db;
use esmith::config;
use esmith::DB::db::Record;
use esmith::DB;
our @ISA = qw(esmith::DB);

=for testing
use_ok('esmith::DB::db');


=head1 NAME

esmith::DB::db - interface to esmith::db databases 

=head1 SYNOPSIS

I<Works just like an esmith::DB class except where noted>

=head1 DESCRIPTION

This module provides an abstracted interface to esmith::db flat-file
databases.  It will read from and write to esmith::db files and can be
safely used right along side esmith::db.  This follows the esmith::DB
interface and will work as documented there unless otherwise stated.

You should use this instead of esmith::db, and replace any existing
esmith::db code with this.

I<Note for esmith::db users> the old concept of a 'type' is now simply
another property.

    my $type = $record->prop('type');

replaces db_get_type().

The $record returned by esmith::DB::db subclass is an esmith::DB::db::Record
subclass object. See the esmith::DB::db manpage for details on how it is used.

=head2 Methods

=over 4

=item B<create>

Puts its error on esmith::DB::db->error

=begin testing

$Scratch_Conf = '10e-smith-lib/scratch.conf';
unlink $Scratch_Conf;
$db = esmith::DB::db->create($Scratch_Conf);
END { unlink $Scratch_Conf }

isa_ok( $db, 'esmith::DB::db', 'create()' );
ok( -e $Scratch_Conf, 'created a new config file' ); 
ok(! esmith::DB::db->create($Scratch_Conf), 
                              'create() wont walk over an existing config' );
like( esmith::DB::db->error, qr/^File exists/,    '  right error message' );

=end testing

=cut

sub create
{
    my ( $class, $file ) = @_;
    $file = $class->_file_path($file);
    my $self;

    eval {
        $self = $class->_init($file);
        croak "File exists" if -e $file;

        $self->{config} = $self->_get_config($file)
          || croak "Can't get the esmith::config object";

        # touch the config file so it gets created immediately
        open( FILE, ">>$file" )
            or die "Failed to open $file for appending: $!\n";
        close FILE;

        # Migrate, and check for errors, propagating them if they happen.
        unless ( $self->migrate() )
        {
            chomp $@;
            $self->set_error($@);
            return;
        }
    };
    if ($@)
    {
        chomp $@;
        $self->set_error($@);
        return;
    }
    return $self;
}

=item B<open>

=for notes
There's currently no way to get the reason why from esmith::config.

=begin testing

unlink $Scratch_Conf;
ok( !esmith::DB::db->open($Scratch_Conf),  'open() on a non-existent db' );
is( esmith::DB::db->error, "File doesn't exist", '  right error' );

esmith::DB::db->create($Scratch_Conf);
$DB = esmith::DB::db->open($Scratch_Conf);
isa_ok( $DB, 'esmith::DB::db' );

=end testing

=cut

sub open
{
    my ( $class, $file ) = @_;
    $file = $class->_file_path($file);
    my $self = $class->_init($file);

    if ( -e $file && !-w $file )
    {
        $self->{ro} = 1;
    }

    return $self->_open($file) ? $self : undef;
}

=item B<open_local>

=for notes
There's currently no way to get the reason why from esmith::config.

=begin testing

unlink $Scratch_Conf;
ok( !esmith::DB::db->open_local($Scratch_Conf), 'open() on a non-existent db' );
is( esmith::DB::db->error, "File doesn't exist", '  right error' );

esmith::DB::db->create($Scratch_Conf);
$DB = esmith::DB::db->open_local($Scratch_Conf);
isa_ok( $DB, 'esmith::DB::db' );

=end testing

=cut

sub open_local
{
    my ( $class, $file ) = @_;
    $file = $class->_file_path($file);
    my $self = $class->_init($file);

    if ( -e $file && !-w $file )
    {
        $self->{ro} = 1;
    }

    return $self->_open($file) ? $self : undef;
}

=begin testing

ok( my $db = esmith::DB::db->open_ro($Scratch_Conf), 
    'open_ro on a non-existent db');
eval { $db->new_record('foo', { type => 'bar' }) };
like( $@, qr/^This DB is opened read-only/ );

=end testing

=cut

sub open_ro
{
    my ( $class, $file ) = @_;
    $file = $class->_file_path($file);
    my $self = $class->_init($file);

    $self->{ro} = 1;

    return $self->_open($file) ? $self : undef;
}

=begin testing

ok( my $db = esmith::DB::db->open_ro_local($Scratch_Conf), 
    'open_ro on a non-existent db');
eval { $db->new_record('foo', { type => 'bar' }) };
like( $@, qr/^This DB is opened read-only/ );

=end testing

=cut

sub open_ro_local
{
    my ( $class, $file ) = @_;
    $file = $class->_file_path($file);
    my $self = $class->_init($file);

    $self->{ro} = 1;

    return $self->_open($file) ? $self : undef;
}


sub is_ro
{
    return $_[0]->{ro} ? 1 : 0;
}

sub _open
{
    my ( $self, $file ) = @_;

    eval {

        # This is unfortunately not atomic, but I don't think
        # that's a big deal.
        die "File doesn't exist\n"  unless -e $file;
        die "File isn't readable\n" unless -r $file;

        $self->{config} = $self->_get_config($file)
          || die "Can't get the esmith::config object";
    };
    if ($@)
    {
        chomp $@;
        $self->set_error($@);
        return;
    }

    return 1;
}

sub _get_config
{
    my ( $self, $file ) = @_;

    my %config;
    tie %config, $self->tie_class, $file;

    return \%config;
}

sub _init
{
    my ( $class, $file ) = @_;

    my $self = bless { file => $file }, $class;

    return $self;
}

sub _file_path
{
    my ( $class, $file ) = @_;

    if ($file =~ m:/:)
    {
	use File::Basename;
	warn "Deprecated pathname $file passed to _file_path()\n"
	    if dirname($file) eq "/home/e-smith";
	return $file;
    }

    if (-e "/home/e-smith/db/$file")
    {
	return "/home/e-smith/db/$file";
    } elsif (-e "/home/e-smith/$file") {
	warn "Database found in old location /home/e-smith/$file";
	return "/home/e-smith/$file";
    } else {
	return "/home/e-smith/db/$file";
    }
}

=item B<as_hash>

=begin testing

use esmith::TestUtils qw(scratch_copy);
my $scratch = scratch_copy('10e-smith-lib/db_dummy.conf');
my %db = esmith::DB::db->as_hash($scratch);

my %expect = (     Foo      => { type => 'Bar' },
                   Night    => { type => 'Day' },
                   Squid    => { type    => 'cephalopod',
                                 arms    => 10,
                                 species => 'Loligo' },
                   Pipe     => { type    => 'art',
                                 pipe    => 'this is not a | got that?',},
                   Haiku    => { type    => 'poem',
                                 words   => 
"Damian Conway\nGod damn! Damian Conway\nDamian Conway",
                               },
                   Octopus  => { type    => 'cephalopod',
                                 arms    => 8,
                                 species => '',
                               }
             );

is_deeply( \%db, \%expect );

%db = esmith::DB::db->open($scratch)->as_hash;
is_deeply( \%db, \%expect );
                   
=end testing

=item B<reload>

=begin testing

my $db2 = esmith::DB::db->open($Scratch_Conf);
my $something = $DB->new_record('something', { type => "wibble" });
isa_ok( $something, 'esmith::DB::db::Record', 'new record in 1st DB' );

ok( !$db2->get('something'),    '  2nd DB still cant see new record' );
ok( $db2->reload,               '  reload' );
ok( $db2->get('something'),     '  2nd DB can see new record' );

$something->delete;

=end testing

=cut

sub reload
{
    my ($self) = shift;

    $self->_open( $self->file );
}

=item B<file>

=for testing
is( $db->file, $Scratch_Conf, 'file()' );

=cut

sub file
{
    my ($self) = shift;
    return $self->{file};
}

=item B<new_record>

=begin testing

my $record = $DB->new_record('Big Brother', { year => 1984,
                                              day => 'night',
                                              type => 'Govt',
                             });
isa_ok( $record, 'esmith::DB::db::Record', 'new_record' );
is( $record->key,  'Big Brother',  'key' );
is( $record->prop('type'), 'Govt',         'type' );
is_deeply( {$record->props}, {year => 1984, day => 'night', type => 'Govt'}, 
                                                           'props' );
is( $record->prop('year'), 1984,        'prop() get' );
is( $record->prop('day'),  'night',     'prop() get again' );


$record = $DB->new_record('No props');
isa_ok( $record, 'esmith::DB::db::Record', 'new_record() w/o props' );
is( $record->key,  'No props', '  key' );

my $db2 = esmith::DB::db->open($DB->file);
ok( $db2->get('No props'), '  can be gotten' );

$record->delete;

=end testing

=cut

sub new_record
{
    my ( $self, $key, $props ) = @_;

    croak "This DB is opened read-only" if $self->is_ro;

    if ( defined db_get( $self->{config}, $key ) )
    {
        return;
    }
    my $type = exists $props->{type} ? delete $props->{type} : '';
    db_set( $self->{config}, $key, $type, $props );
    $self->tie_class->_writeconf($self->{file}, $self->{config});

    return esmith::DB::db::Record->_construct( $self, $key, $self->{config} );
}

=item B<get>

=begin testing

my $rec = $DB->get('Big Brother');
isa_ok( $rec, 'esmith::DB::db::Record', 'get' );
is( $rec->key, 'Big Brother',  '  right key' );

=end testing

=cut

sub get
{
    my ( $self, $key ) = @_;

    unless ( defined db_get( $self->{config}, $key ) )
    {
        return;
    }

    return esmith::DB::db::Record->_construct( $self, $key, $self->{config} );
}

=item B<get_all>

=begin testing 

$DB->new_record('Borg', { type => 'Govt', resistance => 'futile' });
my @records = $DB->get_all;
is( @records, 2, 'get_all' );
ok( !(grep { !$_->isa('esmith::DB::db::Record') } @records),
                                          '  theyre all records' );

=end testing

=cut

sub get_all
{
    my ($self) = shift;

    return
      map { esmith::DB::db::Record->_construct( $self, $_, $self->{config} ) }
      db_get( $self->{config} );
}

=item B<get_all_by_prop>

=begin testing

$DB->new_record('Pretz', { type => 'snack', flavor => 'old fashion' });
my @records = $DB->get_all_by_prop(type => 'Govt');
is( @records, 2, 'get_all_by_prop() type' );
ok( !(grep { $_->prop('type') ne 'Govt' } @records), 
                                   '  theyre the right type' );

$DB->new_record('Pork lips', { type => 'snack', flavor => 'old fashion' });
@records = $DB->get_all_by_prop(flavor => 'old fashion');
is( @records, 2, 'get_all_by_prop()' );
ok( !(grep { $_->prop('flavor') ne 'old fashion' } @records),
                                   '  they have the right properties' );

=end testing

=cut

sub tie_class
{
    return 'esmith::config';
}

sub close
{
}

=begin deprecated

=item B<list_by_type>

Given a type of item to look for in the database (eg "service", "ibay"), 
returns a list of items which are that type.  This is the underlying 
routine behind esmith::AccountsDB::ibays() and similar methods.

=end deprecated

=for testing
ok($DB->list_by_type("Govt"), "list_by_type *deprecated*");

=cut

sub list_by_type
{
    my ( $self, $type ) = @_;

    return map $_->key, $self->get_all_by_prop( type => $type );
}

=back

=head1 EXAMPLE

The full docs can be found in esmith::DB and esmith::DB::Record, but
here's a cheat sheet for esmith::config and esmith::db users.

=over 4

=item opening the default config

    use esmith::config
    my %config;
    tie %config, 'esmith::config;

Now:

    use esmith::ConfigDB;
    my $config = esmith::ConfigDB->open;

=item opening a specific config database

    my %config;
    tie %config, 'esmith::config', $config_file;

Now:

    my $config = esmith::ConfigDB->open($config_file);

=item creating a new config database

This one's important.  Before you could just tie esmith::config to any file
and it would create it for you.  Now you have to explicitly create it.

    my %config;
    tie %config, 'esmith::config', $new_config_file;

Now:

    my $config = esmith::ConfigDB->create($new_config_file);

=item checking if a record exists

    print "Yep" if exists $config{foo};

now:

    print "Yep" if $config->get('foo'); # unless of course, 'foo' is zero

=item creating a new record

Previously you could just create records on the fly:

    # single value
    $config{foo} = 'whatever';

    # with properties
    db_set(\%config, 'whatever', 'sometype', { with => 'properties' });

Now you have to explicitly create them:

    # single value
    my $foo = $config->new_record('foo');
    $foo->set_value('foo');

    # with properties
    my %defaults = ( 'type'    => 'sometype',
                     'linux'   => 'stable',
                     'windows' => 'stable?' );
    my $foo = $config->new_record('foo', \%defaults);

Note that 'type' is now just another property.

Here's a handy "create this if it doesn't already exist" idiom.

    my $rec = $config->get($key) ||
              $config->new_record($key);

=item getting a value

Entries in a database should no longer be thought of as values, but as
records.

    my $val = $config{foo};

Now this only works with entries with single value. Things with
multiple properties are dealt with differently.

    my $record = $config->get('foo');
    my $val = $record->value;

=item setting a value

    $config{foo} = 'something';

now

    my $record = $config->get('foo');
    $record->set_value('something');

=item getting a property

    my $this = db_get_prop(\%config, 'foo', 'this');

now:

    my $foo = $config->get('foo');
    my $this = $foo->prop('this');

=item getting & setting properties

    my $val = db_get_prop(\%config, 'foo', 'some prop');
    db_set_prop(\%config, 'foo', 'some prop' => $new_val);

now:

    my $val = $record->prop('some prop');
    $record->set_prop('some prop' => $new_val);

=item get/setting the type

    my $type = db_get_type(\%config, 'foo');
    db_set_type(\%config, 'foo', $new_type);

type is now just a property

    my $record = $db->get('foo');
    my $type = $record->prop('type');
    $record->set_prop('type', $new_type);

=item getting all the properties

    my %props = db_get_prop(\%config, 'foo');

now

    my %props = $record->props;

=back

=head1 AUTHOR

SME Server Developers <bugs@e-smith.com>

=head1 SEE ALSO

L<esmith::AccountsDB>, L<esmith::ConfigDB>, L<esmith::DB::db::Record>

=cut

1;
