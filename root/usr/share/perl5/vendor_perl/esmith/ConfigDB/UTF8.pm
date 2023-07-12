#----------------------------------------------------------------------
# Copyright 1999-2008 Mitel Networks Corporation
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#----------------------------------------------------------------------

package esmith::ConfigDB::UTF8;

use strict;
use warnings;

use esmith::DB::db;
use esmith::config::utf8;
our @ISA = qw( esmith::DB::db );

sub tie_class
{
    return 'esmith::config::utf8';
}

1;

