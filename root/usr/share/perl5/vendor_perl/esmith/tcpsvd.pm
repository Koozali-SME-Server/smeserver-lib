#----------------------------------------------------------------------
# Copyright 2005-2006 Mitel Networks Corporation
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#----------------------------------------------------------------------

package esmith::tcpsvd;
use strict;

=pod

=head1 NAME

esmith::tcpsvd - Manage tcpsvd "peers" directory

=head1 SYNOPSIS

use esmith::tcpsvd;

esmith::tcpsvd::configure_peers($service)

=head1 DESCRIPTION

This module provides utility functions for use with tcpsvd from Gerrit
Pape's ipsvd package - see http://smarden.org/ipsvd/.

=cut

use esmith::NetworksDB;
use esmith::ConfigDB;
use esmith::util;
use esmith::lockfile;
use Carp;

=head2 configure_peers($service [, $peers_directory] )

configure_peers() configures the "peers" direectory used by tcpsvd for
access control and environment maipulation.  $service identifies the name
of the service managed by supervise or runit. The peers directory (as
specified by the optional $peers_directory argument, defaulting to 
"/var/service/$service/peers") is expected to contain files "0" defining
access conditions for public (default) accesss, and "local", defining
access conditions for local access. configure_peers() creates a set of
symlinks so that tcpsvd uses "local" for all local network access to
the service.

See http://smarden.org/ipsvd/ipsvd-instruct.5.html for all details of
the contents of the peers directory.

=cut

sub configure_peers
{
    my $service = shift;
    my $peers = shift || "/var/service/$service/peers";

    unless (opendir(PEERS, $peers))
    {
	carp "Cannot read peers directory: $!";
	return;
    }

    my $config = esmith::ConfigDB->open;
    unless ($config)
    {
	carp "Could not open config db.";
	return;
    }
    $service = $config->get($service);
    unless ($service)
    {
	carp "No service record for $service";
	return;
    }
    my $access = $service->prop('access') || "localhost";
    my $nets = esmith::NetworksDB->open;
    unless ($nets)
    {
	carp "Could not open networks db.";
	return;
    }

    my $gw = $config->get('GatewayIP');

    # Make a list of local networks, in prefix format
    my %nets = ($access eq "localhost") ? () :
	    map
	    {
		$_ => 1,
	    }
		map
		{
		    esmith::util::computeAllLocalNetworkPrefixes($_->key, $_->prop('Mask'));
		}
		    ($nets->get_all_by_prop('type', 'network'));

    $nets{'127.0.0.1'} = 1;

    # Setup lock on peers directory while we manipulate it
    my $lock = esmith::lockfile::LockFileOrWait("$peers/local");

    # Now manage a set of symlinks to the "local" instructions file
    foreach my $insfile (readdir (PEERS))
    {
	next unless -l "$peers/$insfile";
	if (exists $nets{$insfile})
	{
	    # Cross this one off the list so that we don't bother creating it
	    delete $nets{$insfile};
	}
	else
	{
	    # We no longer need this entry
	    unlink "$peers/$insfile" or
		warn "Could not delete access control file $peers/$insfile: $!\n";
	}
    }
    closedir(PEERS);

    foreach my $insfile (keys %nets)
    {
	symlink "local", "$peers/$insfile" or
	    warn "Cannot add instructions file for $peers/$insfile: $!\n";
    }

    if (defined $gw)
    {
	# We have a defined gateway address - make sure that the router doesn't have
	# relay privileges
	my $gw_ip = $gw->value;
	unlink "$peers/$gw_ip";
	symlink "0", "$peers/$gw_ip" or
	      warn "Cannot add instructions file for $peers/$gw_ip: $!\n";
    }

    # Unlock peers directory
    $lock && esmith::lockfile::UnlockFile($lock);
}

1;
