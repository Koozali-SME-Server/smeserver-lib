#----------------------------------------------------------------------
# Copyright 1999-2003 Mitel Networks Corporation
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#----------------------------------------------------------------------

package esmith::db;

use esmith::config;
use strict;


=head1 NAME

esmith::db - Routines for handling the e-smith configuration database

=head1 SYNOPSIS

B<THIS MODULE HAS BEEN DEPRECATED>

    use esmith::db;
    use esmith::config;

    my %config;
    tie %config, 'esmith::config', $config_file;

    db_set(\%config, $key, $type, \%properties);
    db_set_type(\%config, $key, $type);
    db_set_prop(\%config, $key, $property => $new_value);

    my($type, %properties) = db_get(\%config, $key);
    my $type       = db_get_type(\%config, $key);
    my %properties = db_get_prop(\%config, $key);
    my $value      = db_get_prop(\%config, $key, $property);

    db_delete(\%config, $key);
    db_delete_prop(\%config, $key, $property);

    db_print(\%config, $key);
    db_show(\%config, $key);
    db_print_type(\%config, $key);
    db_print_prop(\%config, $key, $prop);


=head1 DESCRIPTION

B<THIS MODULE HAS BEEN DEPRECATED>.  Please use a subclass of
esmith::DB::db instead, such as esmith::AccountsDB or esmith::ConfigDB.

I<Do not try to change this module>.  Much code depends on subtle
nuances and bugs and you will break things if you try to fix it.
Instead, move any existing code away from esmith::db and towards
esmith::DB::db.


This module provides utility routines for manipulating e-smith 
configuration data. OO and non-OO versions of the routines are provided.
For example, db_set() is the non-OO while set() can be called with an 
object reference.

E-Smith DB entries have three parts.  A key, a type and a hash of
properties.

  key           squid
  type          cephalopod
  properties    arms    => 10
                species => Loligo

=cut

use vars qw($VERSION @ISA @EXPORT);
$VERSION     = sprintf "%d.%03d", q$Revision: 1.16 $ =~ /(\d+)\.(\d+)/;

use Exporter;
@ISA         = qw(Exporter);
@EXPORT      = qw(
                  db_set
                  db_get
                  db_delete

                  db_set_type
                  db_get_type

                  db_get_prop
                  db_set_prop
                  db_delete_prop

                  db_print
                  db_show

                  db_print_type
                  db_print_prop
                 );

=head2 Functions

=over 4

=item B<db_set>

  my $success = db_set(\%config, $key, $raw_value);
  my $success = db_set(\%config, $key, $type);
  my $success = db_set(\%config, $key, $type, \%properties);

Enters a new $key into the %config or replaces an existing $key.  It
sets the $type and optionally %properties.

As a "bug which has become a feature" you can feed db_set() the
$raw_value for a $key (ie. 'type|prop1|val1|prop2|val2') and it will
setup the types and properties properly.  I<Do not depend on this> but
don't change it either.  There's code that depends on this behavior.

It returns true on success, false on failure.

If the $key contains a newline it will fail.

=cut

sub db_set
{
    my ($hash, $key, $new_value, $hashref) = @_;

    return undef if ($key =~ /\n/);
    if (defined $hashref)
    {
        my $properties = _db_hash_to_string($hashref);
        if (defined $properties && $properties ne '')
        {
            $new_value .= "|$properties";
        }
    }
    $new_value and $new_value =~ s/\n/\\n/g;
    $$hash{$key} = $new_value;
    return undef unless defined db_get($hash, $key);
    return 1;
}

=head2 B<db_get>

    my($type, %properties) = db_get(\%config, $key);
    my $raw_value  = db_get(\%config, $key);
    my @keys       = db_get(\%config);

Reads the $type and %properties for the given $key in %config.

In scalar context it returns the raw value of $config{$key} B<NOT> the
type!  But it unescapes newlines.  I<Use db_get_type() instead>.

If a $key is not given it returns all the @keys in the %config.

=cut

sub db_get
{
    my ($hash, $key) = @_;

    return sort keys %$hash unless defined $key;
    return undef unless exists $$hash{$key};

    my $value = $$hash{$key};
    $value and $value =~ s/\\n/\n/g;
    return wantarray() ? _db_string_to_type_and_hash($value) : $value;
}

=item B<db_delete>

  db_delete(\%config, $key)

Deletes the $key from %config.

=cut

sub db_delete
{
    my ($hash, $key) = @_;

    return undef unless defined db_get($hash, $key);

    delete $$hash{$key};
    return 1;
}


=item B<db_set_type>

  my $success = db_set_type(\%config, $key, $type)

Sets the $type for $config{$key}.

Returns true if the set succeeded, false otherwise.

=cut

sub db_set_type
{
    my ($hash, $key, $type) = @_;

    return undef unless defined db_get($hash, $key);

    my %properties = db_get_prop($hash, $key);

    return db_set($hash, $key, $type, \%properties);
}


=item B<db_get_type>

    my $type = db_get_type(\%config, $key);

Returns the $type associated with the $key in the %config database.

Will return undef if the $key doesn't exist.

=cut

sub db_get_type
{
    my ($hash, $key) = @_;

    return undef unless defined db_get($hash, $key);

    my ($type) =
        _db_string_to_type_and_hash(db_get($hash, $key));
    return $type;
}


=item B<db_set_prop>

  my $success = db_set_prop(\%config, $key, $property => $new_value)

Sets the given $property of the $key in the %config database to the
$new_value.  If the $property didn't exist, it will be added.

Returns true/value if it succeeded/failed.

=cut

sub db_set_prop
{
    my ($hash, $key, $prop, $new_value) = @_;

    return undef unless defined db_get($hash, $key);

    my $type = db_get_type($hash, $key);
    my %properties = db_get_prop($hash, $key);
    $properties{$prop} = $new_value;
    return db_set($hash, $key, $type, \%properties);
}


=item B<db_get_prop>

  my %properties = db_get_prop(\%config, $key);    
  my $value      = db_get_prop(\%config, $key, $property);

Returns the %properties for a $key in the %config database.  If you
ask for a specific $property you'll get the $value for that $property.

Returns undef if the $key or $property doesn't exist.

=cut

sub db_get_prop
{
    my ($hash, $key, $prop) = @_;

    my $val = db_get($hash, $key);
    return (defined $prop ? undef : ()) unless defined $val;

    my($type, %properties) = _db_string_to_type_and_hash($val);

    return %properties unless defined $prop;
    return undef unless exists $properties{$prop};
    return $properties{$prop};
}


=item B<db_delete_prop>

  db_delete_prop(\%config, $key, $property)

Deletes a $property from the $key in the %config.

Returns undef if the $key doesn't exist.

=cut

sub db_delete_prop
{
    my ($hash, $key, $prop) = @_;

    return undef unless defined db_get($hash, $key);

    my $type = db_get_type($hash, $key);
    my %properties = db_get_prop($hash, $key);
    delete $properties{$prop};
    return db_set($hash, $key, $type, \%properties);
}

=back

=head2 Debugging Functions

These functions are useful for debugging.

=over 4

=item B<db_print>

  db_print(\%config);
  db_print(\%config, $key);

Prints out keys and raw values in the %config database.  If $key is
given it prints the $key and its raw value.  If no $key is given it
prints out all the keys and their raw values.

=cut

sub db_print
{
    my ($hash, $key) = @_;

    my @list;

    if (defined $key)
    {
        return undef unless defined db_get($hash, $key);
        @list = ($key);
    }
    else
    {
        @list = db_get($hash);
    }

    return undef unless scalar @list;

    foreach (@list)
    {
        print "$_=", scalar db_get($hash, $_),"\n";
    }

    return 1;
}


=item B<db_show>

  db_show(\%config);
  db_show(\%config, $key);

Prints out keys and their values in a human readable format.

If $key is given it prints out the $key, type and properties of that
$key.  Otherwise it prints out the key, type and properties for all
keys.

=cut

sub db_show
{
    my ($hash, $key) = @_;

    my @list;

    if (defined $key)
    {
        return undef unless defined db_get($hash, $key);
        @list = ($key);
    }
    else
    {
        @list = db_get($hash) unless defined $key;
    }

    return undef unless scalar @list;

    foreach (@list)
    {
        print "$_=";

        my $type = db_get_type($hash, $_);

        if (defined $type)
        {
            print "$type\n";
        }
        else
        {
            print "\n";
            next;
        }

        my %properties = db_get_prop($hash, $_);
        next unless scalar keys %properties;

        foreach my $property (sort keys %properties)
        {
            print "    $property=$properties{$property}\n";
        }
    }

    return 1;
}


=item B<db_print_type>

  db_print_type(\%config);
  db_print_type(\%config, $key);

Prints out keys and their types in the %config database.

If $key is given, it prints out just that $key and its type.
Otherwise it prints out all the keys and their types.

=cut

sub db_print_type
{
    my ($hash, $key) = @_;

    my @list;

    if (defined $key)
    {
        return undef unless defined db_get($hash, $key);
        @list = $key;
    }
    else
    {
        @list = db_get($hash);
    }

    return undef unless scalar @list;

    foreach (@list)
    {
        print "$_=";

        my $type = db_get_type($hash, $_);

        print db_get_type($hash, $_),"\n" if defined $type;
        print "\n" unless defined $type;
    }

    return 1;
}


=item B<db_print_prop>

  db_print_prop(\%config, $key);
  db_print_prop(\%config, $key, $property);

Prints out the properties (or a single $property) of the given $key in
the %config.

=cut

sub db_print_prop
{
    my ($hash, $key, $prop) = @_;

    my @list;
    my %list;

    return undef unless defined db_get($hash, $key);

    if (defined $prop)
    {
        my $value = db_get_prop($hash, $key, $prop);
        return undef unless defined $value;

        %list = ($prop => $value);
    }
    else
    {
        %list = db_get_prop($hash, $key);
    }

    return undef unless scalar keys %list;

    foreach (sort keys %list)
    {
        print "$_=$list{$_}\n";
    }

    return 1;
}


=head2 OO Interface

To add to the confusion, esmith::db has a vestigal object-oriented
interface.  Use esmith::DB::db instead.

=over 4

=item B<new>

  my $db = esmith::db->new($db_file)

Generates a new esmith::db object from the given $db_file

=cut

sub new
{
    my($class,$dbname) = @_;

    return $class->open($dbname);
}


=item B<open>

  my $db = esmith::db->open($db_name);
  my $db = esmith::db->open($db_file);

Takes a database name (or pathname) and opens the named database. 
The database name form is preferred over the explicit pathname.

For example

  $db->open( 'configuration' );
              or
  $db->open( '/path/to/configuration' );

=cut

sub open
{
    my $self = shift;
    my $dbName = shift;
    my $class = ref($self) || $self;

    my $dataFile = _db_path($dbName);

    unless ( $esmith::db::REFCOUNT{$dataFile} )
    {
        warn "Reading $dataFile into cache\n" if ($esmith::db::DEBUG);

        my %db;
        tie %db, 'esmith::config', $dataFile;

        $esmith::db::CACHE{$dataFile} = \%db;   
    }

    $self = bless { 
        DBNAME => $dataFile, 
        CACHE => $esmith::db::CACHE{$dataFile} 
    }, $class;

    $esmith::db::REFCOUNT{$dataFile}++;

    return $self;
}

sub DESTROY
{
    my $self = shift;
    return $self->close();
}


=item B<close>

  $db->close;

Closes this database.

=cut

sub close
{
    my $self = shift;

    my $dataFile = $self->{'DBNAME'};

    $esmith::db::REFCOUNT{$dataFile}--;

    if ( $esmith::db::REFCOUNT{$dataFile} == 0 )
    {
        delete $esmith::db::CACHE{$dataFile};
        warn "esmith::db::close Closing $dataFile\n" if ($esmith::db::DEBUG);
    }
    elsif ( $esmith::db::REFCOUNT{$dataFile} > 0 )
    {
        warn "esmith::db::close Not closing $dataFile, references ",
        $esmith::db::REFCOUNT{$dataFile}, "\n" if ($esmith::db::DEBUG);
    }
    else 
    {
        $esmith::db::REFCOUNT{$dataFile} = 0;
        warn "esmith::db::close Not closing $dataFile, zero references\n" 
        if ($esmith::db::DEBUG);
    }
}


=item B<set>

=item B<set_type>

=item B<set_prop>

=item B<get>

=item B<get_type>

=item B<get_prop>

=item B<delete>

=item B<delete_prop>

These all work like their functional versions (ie. set() == db_set())
except it is not necessary to input the %config database.

=cut

sub AUTOLOAD
{
    no strict 'refs';

    # fully qualified sub-name stored in $AUTOLOAD package variable
    $esmith::db::AUTOLOAD =~ /^(.*::)(.*)$/;
    my ($pkg, $sub) = ($1, $2);

    # use *foo{THING} syntax to check if sub is defined (see perlref)
    if (defined *{"${pkg}db_${sub}"}{CODE})
    {
        my $self = shift;
        my $cache = $esmith::db::CACHE{$self->{DBNAME}};
        wantarray ? return (my @p = &{"${pkg}db_${sub}"}($cache, @_))
            : return (my $p = &{"${pkg}db_${sub}"}($cache, @_));
    }
}

=begin private

=head2 Private functions

=over4

=item B<_db_hash_to_string>

  my $raw_value = _db_hash_to_string($hashref);

Takes a reference to a hash and returns a string of pipe "|" delimited
pairs suitable for being stored.

=cut

sub _db_hash_to_string
{
    my ($hash) = @_;
    my $string = '';

    foreach (sort keys %$hash)
    {
        $string .= '|' if length($string);
        $string .= "$_|";
        $string .= $$hash{$_} if defined $$hash{$_};
    }

    return $string;
}

=pod

=item B<_db_string_to_type_and_hash>

  my($type, %properties) = _db_string_to_type_and_hash($raw_value);

Takes the $raw_value, which is a | delimited string, and spits it up
into the $type (the first field) and its %properties (the rest).

Escaped pipes (\|) are properly ignored as a delimiter.

=cut

sub _db_string_to_type_and_hash ($)
{
    my ($arg) = @_;
    return ('', ()) unless defined $arg;

    # The funky regex is to avoid escaped pipes.
    # If you specify a negative limit empty trailing fields are omitted.
    return split(/(?<!\\)\|/, $arg, -1);
}

=item B<_db_path>

  my $dfile = _db_path($database_name);

Takes a $database_name and returns the $file where it lives.

=cut

sub _db_path($)
{
    my ($file) = @_;

    if ($file =~ m:^/:)
    {
	return $file;
    }
    return "/home/e-smith/db/$file" if (-e "/home/e-smith/db/$file");

    if (-e "/home/e-smith/$file")
    {
	warn "Database found in old location /home/e-smith/$file";
	return "/home/e-smith/$file";
    }
    else
    {
	return "/home/e-smith/db/$file";
    }
}

=back

=end private


=head1 BUGS and CAVEATS

keys cannot contain newlines or pipes.  

types and properties cannot contain pipes.


=head1 AUTHOR

Mitel Networks Corporation

For more information, see http://www.e-smith.org/

=cut

1;
