#----------------------------------------------------------------------
# Copyright 1999-2005 Mitel Networks Corporation
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#----------------------------------------------------------------------

package esmith::ethernet;

#----------------------------------------------------------------------

use strict;
use File::Basename;

=head1 NAME

esmith::ethernet - Ethernet-related utility routines for e-smith

=head1 VERSION

This file documents C<esmith::ethernet> version B<1.4.0>

=head1 SYNOPSIS

    use esmith::ethernet;

=head1 DESCRIPTION

This module contains routines for 


=pod

=head2 probeAdapters()

Probe for any recognised adapters

=cut

sub probeAdapters ()
{
    opendir(my $dh, "/sys/class/net") or die "Couldn't open /sys/class/net: $!";
    my @nics = grep { $_ !~ m/^\./ } readdir($dh);
    closedir($dh);
    my $adapters = '';
    my $index = 1;
    foreach my $nic (@nics){
        # Untaint $nic and makes sure the name looks OK
        next unless ($nic =~ m/^(\w+[\.:]?\d+)$/);
        $nic = $1;
        next if (
            # skip loopback
            $nic eq 'lo' ||
            # skip non links
            !-l "/sys/class/net/$nic" ||
            # skip wireless nics
            -d "/sys/class/net/$nic/wireless" ||
            -l "/sys/class/net/$nic/phy80211" ||
            # skip bridges
            -d "/sys/class/net/$nic/bridge" ||
            # skip vlans
            -f "/proc/net/vlan/$nic" ||
            # skip bonds
            -d "/sys/class/net/$nic/bonding" ||
            # skip tun/tap
            -f "/sys/class/net/$nic/tun_flags" ||
            # skip dummy
            -d "/sys/devices/virtual/net/$nic"
        );
        # Now we should be left only wth ethernet adapters
        open HW, "/sys/class/net/$nic/address";
        my $mac = join("", <HW>);
        close HW;
        # Check MAC Addr and untaint it
        next unless ($mac =~ m/^(([\da-f]{2}:){5}[\da-f]{2})$/i);
        $mac = $1;
        # If the device is a slave of a bridge, it's real MAC
        # address can be found in /proc/net/bonding/bondX
        if (-l "/sys/class/net/$nic/master"){
            my $bond = basename (readlink "/sys/class/net/$nic/master");
            local $/ = '';
            open SLAVES, "/proc/net/bonding/$bond";
            my @slaves = <SLAVES>;
            close SLAVES;
            my @slaveInfo = grep { /^Slave\ Interface:\ $nic/m } @slaves;
            foreach (split /\n+/, (join "", @slaveInfo)){
                $mac = $1 if (/^Permanent\ HW\ addr:\ (.*)$/);
            }
        }
        chomp($mac);
        my $driver = basename (readlink "/sys/class/net/$nic/device/driver");
        # Untaint driver name
        next unless ($driver =~ m/^([\w\-]+)$/);
        $driver = $1;
        my $bus = basename (readlink "/sys/class/net/$nic/device/subsystem");
        my $desc = $nic;
        if ($bus eq 'pci'){
            my $dev = basename (readlink "/sys/class/net/$nic/device");
            # Untaint $dev
            if ($dev =~ m/^(\d+:\d+:\d+\.\d+)$/){
                $dev = $1;
                $desc = `/sbin/lspci -s $dev`;
                # Extract only description 
                $desc =~ m/^.*:.*:\s+(.*)\s*/;
                $desc = $1;
            }
        }
        elsif ($bus eq 'virtio'){
            $desc = 'Virtio Network Device';
        }
        # TODO: we should also try to get the description of USB devices
        $adapters .= "EthernetDriver" . $index++ . "\t" . $driver . "\t" .
                     $mac . "\t" . "\"$desc\"" . "\t" . $nic ."\n";
    }
    return $adapters;
}


#----------------------------------------------------------------------
# Return one to make the import process return success.
#----------------------------------------------------------------------

1;

=pod

=AUTHOR

SME Server Developers <bugs@e-smith.com>

For more information see http://www.e-smith.org/

=cut

