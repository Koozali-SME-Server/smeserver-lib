#----------------------------------------------------------------------
# Copyright 1999-2003 Mitel Networks Corporation
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#----------------------------------------------------------------------

package esmith::DB::db::Record;

use strict;
use warnings;
use Carp;

use esmith::db;
use esmith::DB::db;

require esmith::DB::Record;
our @ISA = qw(esmith::DB::Record);


=begin testing

use_ok('esmith::DB::db::Record');
use_ok('esmith::DB::db');

use File::Copy;
$Scratch_Conf = '10e-smith-lib/scratch.conf';
copy('10e-smith-lib/db_dummy.conf', $Scratch_Conf);
END { unlink $Scratch_Conf }

$DB = esmith::DB::db->open($Scratch_Conf);
$Squid = $DB->get('Squid');

=end testing

=head1 NAME

esmith::DB::db::Record - Individual records in an esmith::db database

=head1 SYNOPSIS

Unless otherwise noted, works just like esmith::DB::Record.

=head1 DESCRIPTION

This class represents entries in esmith::db flat-file database.  A
single object is a single line.

This class is not useful by itself but rather they are handed out
via esmith::DB::db objects.


=begin protected

=head2 Protected Methods

These methods are only allowed to be called by esmith::DB::db classes.

=item B<_construct>

  my $record = esmith::DB::db::Record->_construct($db, $key, $config);

Generates a new esmith::DB::db::Record representing data inside the
$db (an esmith::DB::db object).

This does *not* write anything into $db.  This is here so a $db can
initialize a new Record from existing data.

=end protected

=cut

sub _construct {
    my($class, $db, $key, $config) = @_;

    die "_construct may only be called by esmith::DB::db"
      unless caller->isa('esmith::DB::db');
    
    my $self = {
                db      => $db,
                config  => $config,
                key     => $key
               };

    return bless $self, $class;
}

=head2 Methods

=over 4

=item B<key>

=for testing
is( $Squid->key, 'Squid', 'key()' );

=cut

sub key {
    my($self) = shift;
    return $self->{key};
}

=item B<props>

=for testing
is_deeply( {$Squid->props}, {arms => 10, species => 'Loligo', 
                             type => 'cephalopod'},          'props()' );

=cut

sub props {
    my($self) = shift;

    my %props = db_get_prop($self->{config}, $self->{key});
    $props{type} = db_get_type($self->{config}, $self->{key});
    foreach my $prop (keys %props) {
        $props{$prop} =~ s{\\\|}{\|}g if $props{$prop};
    }
    return wantarray ? %props : keys %props;
}

=item B<prop>

=item B<set_prop>

=begin testing

is( $Squid->prop('arms'), 10,     'prop()' );
$Squid->set_prop('arms', 1000);
is( $Squid->prop('arms'), 1000,   'set_prop()' );

is( $Squid->prop('type'), 'cephalopod',         'prop() type get' );
$Squid->set_prop('type', 'tree dweller');
is( $Squid->prop('type'), 'tree dweller',       'set_prop() type set' );

$Squid->set_prop('bar', 'foo | bar');
is( $Squid->prop('bar'), 'foo  bar',           'prop/set_prop with pipes - pipe stripped' );

{
    my $warning = '';
    local $SIG{__WARN__} = sub { $warning = join '', @_ };
    $Squid->prop('bar', 'foo');
    like( $warning, qr/^prop\(\) got extra arguments 'foo'. Maybe you ment set_prop\(\)\?/,  'prop()/set_prop() mixup warns' );

    $warning = '';
    is( $Squid->prop('I_dont_exist'), undef,  'prop() on non-existent prop' );
    is( $warning, '', '  no warning' );

    $warning = '';
    $Squid->set_prop('I_dont_exist', undef);
    is( $Squid->prop('I_dont_exist'), '', 'set_prop() with undef value' );
    is( $warning, '', '  no warning' );
    $Squid->delete_prop('I_dont_exist');
}

=end testing

=cut

sub prop {
    my($self, $property) = splice @_, 0, 2;

    warn sprintf "prop() got extra arguments '%s'. Maybe you ment set_prop()?",
      "@_" if @_;

    my $value;
    if( $property eq 'type' ) {
        $value = db_get_type($self->{config}, $self->{key});
    }
    else {
        $value = db_get_prop($self->{config}, $self->{key}, $property);
    }

    # Unescape escaped pipes.  esmith::db can't do this for us.
    $value =~ s{\\\|}{\|}g if defined $value;

    return $value;
}

sub set_prop {
    my($self, $property, $value) = @_;

    croak "The DB is open read-only" if $self->{db}->is_ro;

    # Strip pipes - we can't safely escape them while some code
    # still expects to split on pipe
    $value =~ s{\|}{}g if defined $value;

    my $ret;
    if( $property eq 'type' ) {
        $ret = db_set_type($self->{config}, $self->{key}, $value);
    }
    else {
        $ret = db_set_prop($self->{config}, $self->{key}, 
                           $property => $value);
    }
    return $ret;
}


=item B<delete_prop>

A special case for esmith::DB::db::Record, you're not allowed to
delete the 'type' property.

=for testing
is( $Squid->delete_prop('species'), 'Loligo', 
                                  'delete_prop() returns the old value' );
is_deeply( {$Squid->props}, {arms => 1000, bar => 'foo  bar',
                             type => 'tree dweller' },
                                  '  and deletes' );

=cut

sub delete_prop {
    my($self, $property) = @_;

    croak "The DB is open read-only" if $self->{db}->is_ro;

    croak "You're not allowed to delete a type from an esmith::DB::db::Record" 
      if $property eq 'type';

    my $val = $self->prop($property);
    db_delete_prop($self->{config}, $self->{key}, $property);
    
    return $val;
}

=item B<merge_props>

=begin testing

my $octopus = $DB->get('Octopus');
$octopus->merge_props( arms => '8 + 2i', name => 'Fluffy', pipe => 'not |');
is_deeply( {$octopus->props}, { arms => '8 + 2i', type => 'cephalopod',
                                species => '', name => 'Fluffy',
                                pipe => 'not ' },   'merge_props()' );
$octopus->merge_props( type => 'foo' );
is_deeply( {$octopus->props}, { arms => '8 + 2i', type => 'foo',
                                species => '', name => 'Fluffy',
                                pipe => 'not ' },   '  with type' );

$octopus->merge_props( { type => 'foo' } );
like( $_STDERR_, qr/^merge_props\(\) was accidentally passed a hash ref/m,
                                       '  anti-hash ref protection');
=end testing

=cut

sub merge_props {
    my($self, %new_props) = @_;

    croak "The DB is open read-only" if $self->{db}->is_ro;

    if( ref $_[1] ) {
        carp("merge_props() was accidentally passed a hash ref");
    }

    my %props = $self->props;
    my %merged_props = (%props, %new_props);

    # Strip out pipes.
    foreach my $prop (keys %merged_props) {
        $merged_props{$prop} =~ s{\|}{}g 
          if defined $merged_props{$prop};
    }

    my $type = delete $merged_props{type};
    db_set($self->{config}, $self->{key}, $type, \%merged_props);
}

=item B<reset_props>

=begin testing

my $octopus = $DB->get('Octopus');

eval { $octopus->reset_props( { type => 'foo' } ); };
like( $_STDERR_, qr/^reset_props\(\) was accidentally passed a hash ref/m,
                                       '  anti-hash ref protection');

$octopus->reset_props( arms => 8, name => 'Rupert', type => 'foo' );
is_deeply( {$octopus->props}, { arms => '8', name => 'Rupert',
                                type => 'foo' },   'reset_props' );

eval { $octopus->reset_props( arms => '8 + 2i', name => 'Fluffy', 
                              pipe => 'not ') };
like( $@, qr/^You must have a type property/,  '  you must have a type');

=end testing

=cut

sub reset_props {
    my($self, %new_props) = @_;

    croak "The DB is open read-only" if $self->{db}->is_ro;

    if( ref $_[1] ) {
        carp("reset_props() was accidentally passed a hash ref");
    }

    die "You must have a type property" unless $new_props{type};

    # Strip out pipes
    foreach my $prop (keys %new_props) {
        $new_props{$prop} =~ s{\|}{}g
          if defined $new_props{$prop};
    }

    my $type = delete $new_props{type} || $self->prop('type');
    db_set($self->{config}, $self->{key}, $type, \%new_props);
}


=item B<delete>

=for testing
my $foo = $DB->get('Foo');
$foo->delete;
ok( !$DB->get('Foo'), 'delete()' );

=cut

sub delete {
    my($self) = shift;

    croak "The DB is open read-only" if $self->{db}->is_ro;
    db_delete($self->{config}, $self->{key});
}

=item B<show>

=begin testing

is( $Squid->show, <<SQUID, 'show' );
Squid
  arms = 1000
   bar = foo  bar
  type = tree dweller
SQUID

=end testing

=back

=head1 SEE ALSO

L<esmith::DB::db>

=cut

1;
