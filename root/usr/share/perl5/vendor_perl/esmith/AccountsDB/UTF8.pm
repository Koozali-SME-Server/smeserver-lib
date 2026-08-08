#----------------------------------------------------------------------
# Copyright 2013-2025 Koozali Foundation inc.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#----------------------------------------------------------------------

package esmith::AccountsDB::UTF8;

use strict;
use warnings;

use esmith::AccountsDB;
use esmith::config::utf8;
use esmith::DB::db;
use utf8;
use Encode qw(encode);
our @ISA = qw(esmith::AccountsDB);

sub tie_class
{
    return 'esmith::config::utf8';
}

sub new_record
{
    my ($self, $key, $props) = @_;

    if(getpwnam(encode('UTF-8', $key)) || getgrnam(encode('UTF-8',$key)))
    {
        warn "Attempt to create account '$key' which already exists ",
            "in passwd";
        return undef;
    }
    return $self->esmith::DB::db::new_record($key, $props);
}


1;

