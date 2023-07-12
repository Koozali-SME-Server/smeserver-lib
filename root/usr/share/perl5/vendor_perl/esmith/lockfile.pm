#----------------------------------------------------------------------
# Copyright 1999-2003 Mitel Networks Corporation
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#----------------------------------------------------------------------

package esmith::lockfile;

use strict;
use vars qw($VERSION @ISA @EXPORT_OK);
use Exporter;
use Fcntl ":flock";
use FileHandle;

@ISA = qw(Exporter);
@EXPORT_OK = qw( 
    LockFileOrReturn LockFileOrWait UnlockFile 
);


sub LockFileOrReturn ($)
{
    # Attempt to lock a file. If the lock fails, return immediately.

    my $lock_file = shift;

    my $FH = new FileHandle;

    $FH->open(">> $lock_file")
        or die "Cannot open lock file $lock_file for writing: $!.\n";

    flock($FH, LOCK_EX | LOCK_NB) or return 0;

    return $FH;
}

sub LockFileOrWait ($)
{
    # Attempt to lock a file. Wait until the file is available.

    my $lock_file = shift;

    my $FH = new FileHandle;

    $FH->open(">> $lock_file")
        or die "Cannot open lock file $lock_file for writing: $!.\n";

    flock($FH, LOCK_EX) or return 0;

    return $FH;
}

sub UnlockFile ($)
{
    my $FH = shift;

    flock($FH, LOCK_UN);
    $FH->close;
}

1;
