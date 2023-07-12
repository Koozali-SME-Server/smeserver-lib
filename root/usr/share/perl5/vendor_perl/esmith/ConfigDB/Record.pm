#----------------------------------------------------------------------
# Copyright 1999-2003 Mitel Networks Corporation
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#----------------------------------------------------------------------

package esmith::ConfigDB::Record;

use strict;
use warnings;

use esmith::ConfigDB;
require esmith::DB::db::Record;
our @ISA = qw(esmith::DB::db::Record);

=head1 NAME

esmith::ConfigDB::Record - record in an esmith::ConfigDB database.

=head1 SYNOPSIS

    Just like esmith::DB::db::Record except...

    my $value = $record->value;
                $record->set_value($value);

=head1 DESCRIPTION

This provides some extra functionality needed by the esmith::ConfigDB
databases.

Unless noted, it works just like esmith::DB::db::Record.

=head2 New Methods


=over 4

=item B<value>

=item B<set_value>

  my $value = $record->value;
              $record->set_value($value);

Gets/sets the value of the $record.  Some ConfigDB entries don't have
a set of properties, but rather a single value.

It will warn if you use these on $records with properties.

=begin testing

use esmith::ConfigDB;
$Scratch_Conf = '10e-smith-lib/scratch.conf';
unlink $Scratch_Conf;
$c = esmith::ConfigDB->create($Scratch_Conf);
END { unlink $Scratch_Conf }

{
    my $warning = '';
    local $SIG{__WARN__} = sub { $warning = join '', @_ };

    my $wib = $c->new_record('wibble', { type => 'yar' });
    $wib->set_value('foo');
    is( $wib->value, 'foo',  'value/set_value' );
    is( $warning, '',        '  no warning' );

    $wib->set_prop(bar => 42);
    is( $wib->value, 'foo' );
    like( $warning, qr/value\(\) should not be used on records with properties, use prop\(\)/, 'value() warns if the record has props');

    $wib->set_value(92);
    like( $warning, qr/set_value\(\) should not be used on records with properties, use set_prop\(\)/, 'value() warns if the record has props');
    is( $wib->value, 92 );
}


=end testing

=cut

sub value {
    my($self) = shift;

    my %props = $self->props;
    warn "value() should not be used on records with properties, use prop()" if
      keys %props > 1;
    return $self->prop('type');
}

sub set_value {
    my($self, $value) = @_;

    my %props = $self->props;
    warn "set_value() should not be used on records with properties, ".
         "use set_prop()" if keys %props > 1;
    return $self->set_prop('type', $value);
}

=back

=head1 SEE ALSO

L<esmith::ConfigDB>, L<esmith::DB::db::Record>

=cut

1;
