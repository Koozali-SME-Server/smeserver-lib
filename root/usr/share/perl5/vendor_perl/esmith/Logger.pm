#----------------------------------------------------------------------
# Copyright 1999-2003 Mitel Networks Corporation
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#----------------------------------------------------------------------

package esmith::Logger;

use Sys::Syslog qw(:DEFAULT setlogsock);

=head1 NAME

esmith::Logger - A filehandle abstraction around Syslog.

=head1 SYNOPSIS

    use esmith::Logger;

    tie *FH, 'esmith::Logger';
    print FH "log message";
    close FH;

=head1 DESCRIPTION

=cut

our $VERSION = sprintf '%d.%03d', q$Revision: 1.100 $ =~ /: (\d+).(\d+)/;

sub TIEHANDLE
{
    my $class = ref($_[0]) || $_[0]; shift;
    my $self;
    my $title = shift || 'e-smith';
    setlogsock 'unix';
    openlog($title, 'pid', 'local1');
    return bless \$self, $class;
}

sub PRINT
{
    my $self = shift;
    syslog('info', "%s", "@_");
}

sub PRINTF
{
    my $self = shift;
    my $fmt = shift;
    syslog('info', $fmt, @_);
}

sub WRITE
{
    die "Sorry, WRITE unimplemented.\n";
}

sub READ
{
    die "Can't read from logger.\n";
}

sub READLINE
{
    die "Can't read from logger.\n";
}

sub GETC
{
    die "Can't read from logger.\n";
}

sub CLOSE
{
    closelog();
}

1;
