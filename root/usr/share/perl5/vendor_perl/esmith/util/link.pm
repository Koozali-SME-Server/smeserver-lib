#----------------------------------------------------------------------
# Copyright 1999-2003 Mitel Networks Corporation
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#----------------------------------------------------------------------

package esmith::util::link;

use strict;
use esmith::ConfigDB;
require Exporter;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(getExternalLink);

=head1 NAME

esmith::util::link - utilities for manipulating network links

=head1 SYNOPSIS

  use esmith::util::link qw(getExternalLink);

  # wait at most 60 seconds for the link to come up
  my $timeout = 60; 

  # now just get the link
  if (getExternalLink($timeout))
  {
    # the link is up
  }
  else
  {
    # the link didn't come up
  }

=head1 DESCRIPTION

This is a collection of generally useful functions for manipulating network 
links.

Functions are exported only on request.

=head2 Functions

=over 4

=item I<getExternalLink($timeout)>

Bring up the external link if it is not already up, waiting at most $timeout
seconds.  If a $timeout is not specified, it defaults to 300 (5 minutes) for
dialup connections.  This function can be used for both dialup and dedicated
connections, but dedicated connections will always return 1 (true).

Returns 1 if the external link is already up, or if it comes up within the
specfied $timeout period.

Returns 0 if the external link does not come up within the specified $timeout
period.

=cut

sub getExternalLink
{
   my $timeout = shift;

   my $configdb = esmith::ConfigDB->open;
   my $rec = $configdb->get("AccessType");
   my $accessType = $rec->value;
   if ($accessType eq "dialup")
   {
      return _getDialupLink($timeout);  
   }
   elsif ($accessType eq "dedicated")
   {
      # assume we are up
      return 1;
   }
   else
   {
      # unknown access type
      return 0;
   }
}

=begin _private

=item I<getDialupLink($timeout)>

Bring up the ppp0 link, waiting at most $timeout seconds.  

Returns 1 if the link comes up within the timeout period.

Returns 0 if the link does not come up within the timeout period.

The default timeout is 300 seconds.

=end _private
=cut

sub _getDialupLink
{
    local $|=1;
    my $timeout = shift(@_) || 300;
 
    # check for existing ppp link
    if (-f "/var/run/ppp0.pid") 
    {
       # already up - return 1
       return 1;
    }
 
    # create a diald monitor channel
    my $ctlFile = "/etc/diald/diald.ctl";
    my $monFile = "/tmp/diald.monitor.$$";
    system('/bin/mknod', $monFile, 'p') == 0 
	or die "Can't mknod $monFile: $!\n";
 
    # open control channel to diald
    open (CTL, ">$ctlFile") or die "Can't open $ctlFile: $!\n";
 
    # set up a child process to monitor the channel

    my $pid = fork;
    die "Can't fork: $!" unless defined $pid;
    if ($pid) 
    {
        # parent

	# if the pipe reader isn't up first, diald will bail, so we open
	# another pipe writer just to wait for the pipe reader
	open (MON_W, ">$monFile") or die "can't open $monFile: $!\n";

        # begin monitoring diald status via monitor fifo
        print CTL "monitor $monFile\n";
        close CTL;

	# ok, everything is up and ready - send USR1 to diald
	open (PID, "</var/run/diald.pid") 
	    or die "can't open diald pidfile: $!\n";
        my $dialdPid = <PID>;
	close PID;
	kill 'USR1', $dialdPid;

        # Wait for the child to exit, then check for link again
        waitpid($pid, 0);
	close MON_W;
    }
    else
    {
        # child

        open (MON, "<$monFile") or die "Can't open $monFile: $!\n";

        # Parse the diald monitor stream for state information
        my $state = "";
        my $elapsed = 0;
        while (<MON>)
        {
	    # lucky us; diald sends a STATUS msg every second
	    if (/^STATUS/) 
            { 
		$elapsed++; 
		if ($elapsed >= $timeout) 
		{ 
		    # time is up - exit with failure code
		    exit 1; 
		}
	    }
	    elsif (/^STATE/) 
            { 
		$state = $_; 
	    }
            elsif ($state eq 'UP') 
            { 
		# the link is up - exit with success code
		exit 0; 
	    }
            next;
        }
        close MON;
	# end child
    }

    # parent (cont)

    unlink $monFile;

    if ($? == 0 || -f "/var/run/ppp0.pid") 
    {
       # ok we're up - return 1 (true)
       return 1;
    }
    else
    {
       # out of time - return 0 (false)
       return 0;
    }
}

1;
