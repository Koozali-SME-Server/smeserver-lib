#----------------------------------------------------------------------
# Copyright 1999-2008 Mitel Networks Corporation
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#----------------------------------------------------------------------

package esmith::config::utf8;
use warnings;
use strict;

use vars qw(@ISA);
@ISA = qw(esmith::config);

sub _read_binmode
{
    return ":encoding(UTF-8)";
}

sub _write_binmode
{
    return ":utf8";
}

1;

