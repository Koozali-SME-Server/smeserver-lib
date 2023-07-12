#----------------------------------------------------------------------
# Copyright 1999-2003 Mitel Networks Corporation
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#----------------------------------------------------------------------

package esmith::util::system;

use strict;
require Exporter;
our @ISA = qw(Exporter);

our @EXPORT_OK = qw(killall rsync rsync_ssh);

=for testing
use_ok('esmith::util::system', 'killall', 'rsync', 'rsync_ssh');


=head1 NAME

esmith::util::system - replacements/wrappers for system() commands

=head1 SYNOPSIS

  use esmith::util::system qw(killall rsync rsync_ssh);

  killall($signal, @commands);
  rsync($src, $dest, @options);
  rsync_ssh($src, $dest, $user, $ident, \@rsync_opts, \@ssh_opts);

=head1 DESCRIPTION

This is for common functions that would normally require a system(...) 
command.  Makes things easier to document, test and upgrade.

If you find yourself writing a system() command, consider putting it
in here.


=head2 Functions

These may be pure Perl functions or they may well just be wrappers
around system() commands.

Each can be imported on request.

=over 4

=item B<killall>

  my $killed_something = killall($signal, @commands);

Sends a $signal to all of the named @commands.  $signal can be
specified by name or number (so 1 or HUP for example, names are
prefered).

Returns true if something was killed, false otherwise.

=begin testing

open(SCRATCH, ">scratch.exe") || die $!;

# XXX Irritating perl bug ends POD processing if it sees /^#!.*perl/
print SCRATCH sprintf <<'ENDING', '/usr/bin/perl';
#!%s -w

sleep 99;
ENDING

close SCRATCH;

END { unlink 'scratch.exe', 'scratch.out' }

chmod 0755, 'scratch.exe' || die $!;
my $pid = open(SCRATCH, "./scratch.exe |");
ok( $pid, 'scratch program started ok' );

ok( killall('USR1', 'scratch.exe'),     'killall returned properly' );
close SCRATCH;  # so scratch.exe responds to the signal and exits

is( kill(9, $pid), 0,    'killall worked' );

# I can't actually think of a way to explicitly check this but it
# will make noise if it doesn't work.
ok( !killall('USR1', 'I_dont_exist_nope'), 
    'returned properly for killing nothing' );
ok( 1, 'killall is quiet when nothing is killed' );

=end testing

=cut

sub killall {
    my($signal, @commands) = @_;

    warn "You don't need a - on the signal" if $signal =~ /^-/;

    my $killed_something = 
          system('/usr/bin/killall', '-q', "-$signal", @commands);

    return !$killed_something;
}

=back

=item B<rsync>

    my $success = rsync($source, $destination, @options);

rsyncs the $source file or directory to the $destination.  Any
@options are direct options to the rsync command.

rsync will be run --quiet by default.

Returns true if the rsync succeeds, false otherwise.

=begin testing

use File::Compare;
my $src  = '10e-smith-lib/db.t';
my $dest = '10e-smith-lib/db.t.copy';
rsync($src, $dest);
END { unlink $dest }

ok( -e $dest );
ok( compare($src, $dest) == 0, 'basic rsync copy' );

open(DEST, ">$dest" ) || die $!;
print DEST "Fooble\n";
close DEST;

# rsync in update-only mode.  $dest is newer than $src and shouldn't
# be updated.
rsync($src, $dest, qw(--update));

ok( compare($src, $dest) == 1,  'rsync, update only' );

open(DEST, "$dest") || die $!;
my $data = join '', <DEST>;
close DEST;

is( $data, "Fooble\n" );

=end testing

=cut

our $RSYNC_CMD = '/usr/bin/rsync';
sub rsync {
    my($src, $dest, @options) = @_;

    push @options, '--quiet';
    return !system($RSYNC_CMD, @options, $src, $dest);
}

=item B<rsync_ssh>

    my $success = rsync_ssh($src, $dest, $user, $ident, \@rsync_opts, 
                                                        \@ssh_opts);

Like rsync() except it uses ssh.  A typical call might be:

    rsync_ssh('some.host:', 'some/file', 'someuser', 'some/.ssh/identity',
              [qw(--archive --delete)]);

=begin testing

use File::Compare;
my $src  = '10e-smith-lib/db.t';
my $dest = '10e-smith-lib/db.t.copy';

unlink $dest;
END { unlink $dest }

no warnings 'once';
my @args;
my $real_rsync = \&esmith::util::system::rsync;
local *esmith::util::system::rsync = sub {
    @args = @_;

    pop @_;
    $real_rsync->(@_);
};
        
rsync_ssh($src, $dest, 'someone', 'some/ident', [qw(--update)], [qw(-C)]);
ok( -e $dest );
ok( compare($src, $dest) == 0 );

is($args[0], $src );
is($args[1], $dest );
is($args[2], '--update' );
is($args[3], "-e $esmith::util::system::SSH_CMD -l someone -i some/ident -C");

=end testing

=cut

our $SSH_CMD = '/usr/bin/ssh';                
sub rsync_ssh {
    my($src, $dest, $user, $ident, $rsync_opts, $ssh_opts) = @_;

    $ssh_opts ||= [];
    my $ssh_opt = join ' ', ('-e', $SSH_CMD, '-l', $user, '-i', $ident, 
                             @$ssh_opts);

    return rsync($src, $dest, @$rsync_opts, $ssh_opt);
}

=head1 AUTHOR

Mitel Networks Corporation

=cut

1;
