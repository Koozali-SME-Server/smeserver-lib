#----------------------------------------------------------------------
# Copyright 2013-2025 Koozali Foundation inc.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#----------------------------------------------------------------------

package esmith::HostsDB::UTF8;

use strict;
use warnings;

use esmith::HostsDB;
use esmith::config::utf8;
our @ISA = qw(esmith::HostsDB);

sub tie_class
{
    return 'esmith::config::utf8';
}

1;

