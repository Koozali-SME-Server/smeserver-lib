#----------------------------------------------------------------------
# Copyright 1999-2003 Mitel Networks Corporation
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#----------------------------------------------------------------------

package esmith::DB::Record;

use strict;
use warnings;
use esmith::DB;

our $VERSION = sprintf '%d.%03d', q$Revision: 1.6 $ =~ /: (\d+).(\d+)/;

=head1 NAME

esmith::DB::Record - an individual record in an E-Smith database

=head1 SYNOPSIS

B<DO NOT USE THIS CLASS DIRECTLY!>  use via esmith::DB.

    my $key  = $record->key;

    my %properties = $record->props;

    my $value = $record->prop($prop_key);
                $record->set_prop($prop_key, $prop_val);

    my $value = $record->delete_prop($prop_key);

    $record->merge_props(%more_properties);
    $record->reset_props(%new_properties);

    $record->delete;

    print $record->show;

=head1 DESCRIPTION

This class is a general interface to individual records in esmith::DB
databases.  It should not be used directly, but rather esmith::DBs
should hand you esmith::DB::Record objects.

Each subclass of esmith::DB will also have to subclass and implement
an esmith::DB::Record subclass.


=head2 Virtual Methods

=over 4

=item B<key>

  my $key = $record->key;

Returns the $key for this $record;

=item B<props>

  my %properties = $record->props;
  my $num_props  = $record->props;

Returns a hash of all the properties for this $record.  In scalar
context it will return the number of properties this $record has.

=item B<prop>

=item B<set_prop>

  my $value = $record->prop($property);
              $record->set_prop($property, $value);

Gets/sets the $value of the $property in this $record.

set_prop() will die if the database is read-only.

=item B<delete_prop>

  my $value = $record->delete_prop($property);

Deletes a $property from the $record, returning the old $value.

delete_prop() will die if the database is read-only.

=item B<merge_props>

  $record->merge_props(%properties);

Adds the %properties to the $records existing properties.  Any new
keys will be added, any existing keys will be overwritten.

merge_props() will die if the database is read-only.

=item B<reset_props>

  $record->reset_props(%properties);

Replaces the $record's properties with the contents of %properties.
Any old properties will be deleted.

reset_props() will die if the database is read-only.

=item B<delete>

  $record->delete;

Deletes the $record from its database.

delete() will die if the database is read-only.

=back


=head2 Concrete methods

=over 4

=item B<show>

  my $formatted = $record->show;

Returns the $record's key and properties in a nice, human readable
format suitable for printing.

=cut

sub show {
     my($self) = shift;

     my $out = $self->key."\n";

     my %props = $self->props;

     # Determine our longest key so we know how to format.
     my $max_len = 0;
     foreach (keys %props) { $max_len = length if length > $max_len }

     # But don't go too far.
     $max_len = 40 if $max_len > 40;

     foreach my $prop (sort { $a cmp $b } keys %props) {
         $out .= sprintf "  %${max_len}s = %s\n", $prop, $props{$prop};
     }

     return $out;
}

=back

=head1 SEE ALSO

L<esmith::DB>

=cut

1;
