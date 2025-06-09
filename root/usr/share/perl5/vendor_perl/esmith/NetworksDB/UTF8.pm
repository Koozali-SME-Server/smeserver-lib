#----------------------------------------------------------------------
# Copyright 2013-2025 Koozali Foundation inc.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#----------------------------------------------------------------------

package esmith::NetworksDB::UTF8;

use strict;
use warnings;

use esmith::NetworksDB;
use esmith::config::utf8;
our @ISA = qw(esmith::NetworksDB);

sub tie_class
{
    return 'esmith::config::utf8';
}

1;

