#----------------------------------------------------------------------
# Copyright 1999-2003 Mitel Networks Corporation
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#----------------------------------------------------------------------

package esmith::DomainsDB;

use strict;
use warnings;

use esmith::DB::db;
our @ISA = qw( esmith::DB::db );

=head1 NAME

esmith::DomainsDB - interface to esmith domains database

=head1 SYNOPSIS

    use esmith::DomainsDB;
    my $c = esmith::DomainsDB->open;

    # everything else works just like esmith::DB::db

=head1 DESCRIPTION

This module provides an abstracted interface to the esmith domain
database.

Unless otherwise noted, esmith::DomainsDB acts like esmith::DB::db.

=cut

=head2 open()

Like esmith::DB->open, but if given no $file it will try to open the
file in the ESMITH_DOMAINS_DB environment variable or domains.

=begin testing

use_ok("esmith::DomainsDB");

$C = esmith::DomainsDB->open('10e-smith-lib/domains.conf');
isa_ok($C, 'esmith::DomainsDB');
is( $C->get("test")->prop('foo'), "bar", 
                                    "We can get stuff from the db");

=end testing

=cut

sub open {
    my ($self, $file) = @_;
    $file = $file || $ENV{ESMITH_DOMAINS_DB} || "domains";
    return $self->SUPER::open($file);
}

=head2 open_ro()

Like esmith::DB->open_ro, but if given no $file it will try to open the
file in the ESMITH_DOMAINS_DB environment variable or domains.

=begin testing

=end testing

=cut

sub open_ro {
    my($class, $file) = @_;
    $file = $file || $ENV{ESMITH_DOMAINS_DB} || "domains";
    return $class->SUPER::open_ro($file);
}
=for testing
$C = esmith::DomainsDB->open('10e-smith-lib/domains.conf');
isa_ok($C, 'esmith::DomainsDB');
can_ok($C, 'domains');
can_ok($C, 'get_all_by_prop');
is(scalar($C->domains()), 2, "Found 2 domains with domains()");

=cut

sub domains {
    my ($self) = @_;
    return $self->get_all_by_prop(type => 'domain');
}

=head1 AUTHOR

SME Server Developers <bugs@e-smith.com>

=head1 SEE ALSO

L<esmith::ConfigDB>

=cut

1;
