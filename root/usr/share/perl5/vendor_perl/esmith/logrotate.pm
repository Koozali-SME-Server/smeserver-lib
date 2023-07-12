#----------------------------------------------------------------------
# Copyright 1999-2003 Mitel Networks Corporation
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#----------------------------------------------------------------------

package esmith::event;

use strict;

=pod

=head1 NAME

esmith::logrotate - Routines for handling rotation of log files

=head1 SYNOPSIS

    use esmith::logrotate;

    NewLogFileSymlink($file);
    MakeFilenameFromSymlink($file);

=head1 DESCRIPTION

=cut

BEGIN
{
}

sub NewLogFileSymlink
{
    my $file = shift;
    unless (defined $file)
    {
	warn("newlogfilesymlink called with no argument");
	return;
    }

    my $time = time();

    if (-f "/var/log/${file}")
    {
	my ($sec,$min,$hour,$mday,$mon,$year) = localtime($time - 1);
	my $target = sprintf("%s%04d%02d%02d%02d%02d%02d",
	    $file, $year+1900, $mon, $mday, $hour, $min, $sec);
	move("/var/log/${file}", "/var/log/${target}") or
	    die "Could not move /var/log/${file} to /var/log/${target}";
    }

    my ($sec,$min,$hour,$mday,$mon,$year) = localtime($time);
    my $target = sprintf("%s%04d%02d%02d%02d%02d%02d",
	$file, $year+1900, $mon, $mday, $hour, $min, $sec);
    unlink("/var/log/${file}") or
	warn "Could not unlink /var/log/${file}";
    symlink("/var/log/${target}", "/var/log/${file}") or
	warn "Could not symlink /var/log/${target} to /var/log/${file}";
}

sub MakeFilenameFromSymlink
{
    use File::Basename;
    my $filename = shift;

    return $filename unless (-l $filename);
    my $link = readlink $filename;
    my $directory = dirname($filename);
    return "${directory}/${link}";
}

END
{
}

1;
