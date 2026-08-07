#----------------------------------------------------------------------
# Copyright 1999-2003 Mitel Networks Corporation
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#----------------------------------------------------------------------

package esmith::util;

use strict;

use Text::Template 'fill_in_file';
use POSIX qw (setsid);
use Errno;
use Carp;
use esmith::config;
use esmith::db;
use esmith::DB;
use esmith::ConfigDB;
use Net::IPv4Addr qw(:all);
use Taint::Util;
use File::Basename;
use File::stat;
use FileHandle;
use Data::UUID;
=pod

=head1 NAME

esmith::util - Utilities for e-smith server and gateway development

=head1 VERSION

This file documents C<esmith::util> version B<1.4.0>

=head1 SYNOPSIS

    use esmith::util;

=head1 DESCRIPTION

This module provides general utilities of use to developers of the
e-smith server and gateway.

=head1 GENERAL UTILITIES

=head2 setRealToEffective()

Sets the real UID to the effective UID and the real GID to the effective
GID.

=begin testing

use_ok('esmith::util');

=end testing

=cut

sub setRealToEffective ()
{
    $< = $>;
    $( = $);
}

=pod

=head2 processTemplate({ CONFREF => $conf, TEMPLATE_PATH => $path })

B<Depreacted> interface to esmith::templates::processTemplate().

=cut

sub processTemplate
{
    require esmith::templates;
    goto &esmith::templates::processTemplate;
}

#------------------------------------------------------------

=pod

=head2 chownfile($user, $group, $file)

This routine changes the ownership of a file, automatically converting
usernames and groupnames to UIDs and GIDs respectively.

=cut

sub chownFile ($$$)
{
    my ( $user, $group, $file ) = @_;

    unless ( -e $file )
    {
        warn("can't chownFile $file: $!\n");
        return;
    }
    my $uid = defined $user  ? getpwnam($user)  : stat($file)->uid;
    my $gid = defined $group ? getgrnam($group) : stat($file)->gid;

    chown( $uid, $gid, $file );
}

=pod

=head2 determineRelease()

Returns the current release version of the software.

=cut

sub determineRelease()
{
    my $unknown = "(unknown version)";

    my $db = esmith::ConfigDB->open() or return $unknown;

    my $sysconfig = $db->get("sysconfig") or return $unknown;

    my $release = $sysconfig->prop("ReleaseVersion") || $unknown;

    return $release;
}

=pod

=head1 NETWORK ADDRESS TRANSLATION UTILITIES

=head2 IPquadToAddr($ip)

Convert IP address from "xxx.xxx.xxx.xxx" notation to a 32-bit
integer.

=cut

sub IPquadToAddr ($)
{
    my ($quad) = @_;
    return 0 unless defined $quad;
    if ( $quad =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)$/ )
    {
        return ( $1 << 24 ) + ( $2 << 16 ) + ( $3 << 8 ) + $4;
    }
    return 0;
}

=pod

=head2 IPaddrToQuad($address)

Convert IP address from a 32-bit integer to "xxx.xxx.xxx.xxx"
notation.

=cut

sub IPaddrToQuad ($)
{
    my ($addrBits) = @_;
    return sprintf( "%d.%d.%d.%d",
        ( $addrBits >> 24 ) & 0xff,
        ( $addrBits >> 16 ) & 0xff,
        ( $addrBits >> 8 ) & 0xff,
        $addrBits & 0xff );
}

=pod

=head2 IPaddrToBackwardQuad($address)

Convert IP address from a 32-bit integer to reversed
"xxx.xxx.xxx.xxx.in-addr.arpa" notation for BIND files.

=cut

sub IPaddrToBackwardQuad ($)
{
    my ($addrBits) = @_;
    return sprintf(
        "%d.%d.%d.%d.in-addr.arpa.",
        $addrBits & 0xff,
        ( $addrBits >> 8 ) & 0xff,
        ( $addrBits >> 16 ) & 0xff,
        ( $addrBits >> 24 ) & 0xff
    );
}

=pod

=head2 computeNetworkAndBroadcast($ipaddr, $netmask)

Given an IP address and netmask (both in "xxx.xxx.xxx.xxx" format)
compute the network and broadcast addresses and output them in the
same format.

=cut

sub computeNetworkAndBroadcast ($$)
{
    my ( $ipaddr, $netmask ) = @_;

    my ( $network, $msk ) = ipv4_network( $ipaddr, $netmask );
    my $broadcast = ipv4_broadcast( $ipaddr, $netmask );

    return ( $network, $broadcast );
}

=pod

=head2 computeLocalNetworkPrefix($ipaddr, $netmask)

Given an IP address and netmask, the computeLocalNetworkPrefix
function computes the network prefix for local machines.

i.e. for an IP address of 192.168.8.4 and netmask of 255.255.255.0,
this function will return "192.168.8.".

This string is suitable for use in configuration files (such as
/etc/proftpd.conf) when the more precise notation

    xxx.xxx.xxx.xxx/yyy.yyy.yyy.yyy

is not supported.

=cut

sub computeLocalNetworkPrefix ($$)
{
    my ( $ipaddr, $netmask ) = @_;

    my ( $net, $msk ) = ipv4_network( $ipaddr, $netmask );
    $net =~ s/(\d{1,3}\.\d{1,3}\.\d{1,3}\.)(\d{1,3})/$1/;

    return $net;
}

=pod

=head2 computeAllLocalNetworkPrefixes ($ipaddress, $netmask)

 Given an IP address and netmask, the computeAllLocalNetworkPrefixes
 function computes the network prefix or list of prefixes that
 fully describe the network to which the IP address belongs.

 examples:

 - for an IP address of 192.168.8.4 and netmask of 255.255.255.0,
 will return an array with a first (and only) element of "192.168.8".

 - for an IP address of 192.168.8.4 and netmask of 255.255.254.0,
 will return the array [ '192.168.8', '192.168.9' ].

 This array is suitable for use in configuration of tools such as
 djbdns where other network notations are not supported.

=begin testing

is_deeply(
    [esmith::util::computeAllLocalNetworkPrefixes("192.168.8.4",
                            "255.255.254.0")],
    ['192.168.8', '192.168.9' ],
    "/23 network"
    );

is_deeply(
    [esmith::util::computeAllLocalNetworkPrefixes("192.168.8.4",
                            "255.255.255.255")],
    ['192.168.8.4'],
    "/32 network"
    );

is_deeply(
    [esmith::util::computeAllLocalNetworkPrefixes("192.168.8.4",
                            "255.255.255.0")],
    ['192.168.8'],
    "/24 network"
    );

=end testing

=cut

sub computeAllLocalNetworkPrefixes
{
    my ( $ipaddr, $netmask ) = @_;

    my $ipaddrBits  = IPquadToAddr($ipaddr);
    my $netmaskBits = IPquadToAddr($netmask);
    my $networkBits = $ipaddrBits & $netmaskBits;

    # first, calculate the prefix (/??) given the netmask
    my $len = 0;
    for ( my $bits = $netmaskBits ; $bits & 0xFFFFFFFF ; $bits <<= 1 )
    {
        $len++;
    }

    # Here's where the magic starts...
    #
    # next, calculate the number of networks we expect to generate and
    # the incrementing value for each network.
    my $number_of_nets = 1 << ( ( 32 - $len ) % 8 );
    my $one_net = 1 << ( 3 - ( int $len / 8 ) ) * 8;
    my @networks;
    while ( $number_of_nets-- )
    {
        my $network = IPaddrToQuad($networkBits);

        # we want to strip off the trailing ``.0'' for /24 or larger networks
        if ( $len <= 24 )
        {
            $network =~ s/\.0$//;
        }

        # we want to continue to strip off trailing ``.0'', one more for
        # /9 to /16, two more for /1 to /8
        $network =~ s/\.0$// if ( $len <= 16 );
        $network =~ s/\.0$// if ( $len <= 8 );

        # push the resulting network into an array that we'll return;
        push @networks, $network;

        # increment the network by ``one'', relative to the size of networks
        # we're dealing with
        $networkBits += $one_net;
    }
    return (@networks);
}

=pod

=head2 computeLocalNetworkShortSpec($ipaddr, $netmask)

Given an IP address and netmask, the computeLocalNetworkShortSpec
function computes a valid xxx.xxx.xxx.xxx/yyy specifier where yyy
is the number of bits specifying the network.

i.e. for an IP address of 192.168.8.4 and netmask of 255.255.255.0,
this function will return "192.168.8.0/24".

This string is suitable for use in configuration files (such as
/etc/proftpd.conf) when the more precise notation

    xxx.xxx.xxx.xxx/yyy.yyy.yyy.yyy

is not supported.

=cut

sub computeLocalNetworkShortSpec ($$)
{
    my ( $ipaddr, $netmask ) = @_;
    my ( $net, $mask ) = ipv4_network( $ipaddr, $netmask );
    return "$net/$mask";
}

=pod

=head2 computeLocalNetworkSpec($ipaddr, $netmask)

Given an IP address and netmask, the computeLocalNetworkSpec function
computes a valid xxx.xxx.xxx.xxx/yyy.yyy.yyy.yyy specifier.

=cut

sub computeLocalNetworkSpec ($$)
{
    my ( $ipaddr, $netmask ) = @_;
    my ( $net, $mask ) = ipv4_network( $ipaddr, $netmask );
    $mask = ipv4_cidr2msk($mask);
    return "$net/$mask";
}

=pod

=head2 computeNetmaskFromBits ($bits)

Given a number of bits of network address, calculate the appropriate
netmask.

=cut

sub computeNetmaskFromBits ($)
{
    my ($ones) = @_;

    return ipv4_cidr2msk($ones);
}

=pod

=head2 computeLocalNetworkReversed($ipaddr, $netmask)

Given an IP address and netmask, the computeLocalNetworkReversed
function computes the appropriate DNS domain field.

NOTE: The return value is aligned to the next available byte boundary, i.e.

     192.168.8.4/255.255.255.0 returns "8.168.192.in-addr.arpa."
     192.168.8.4/255.255.252.0 returns "168.192.in-addr.arpa."
     192.168.8.4/255.255.0.0   returns "168.192.in-addr.arpa."
     192.168.8.4/255.252.0.0   returns "192.in-addr.arpa."
     192.168.8.4/255.0.0.0     returns "192.in-addr.arpa."

This string is suitable for use in BIND configuration files.

=cut

sub computeLocalNetworkReversed ($$)
{
    my ( $ipaddr, $netmask ) = @_;

    my @addressBytes = split ( /\./, $ipaddr );
    my @maskBytes    = split ( /\./, $netmask );

    my @result;

    push ( @result, "in-addr.arpa." );

    foreach (@maskBytes)
    {
        last unless ( $_ eq "255" );

        unshift ( @result, shift (@addressBytes) );
    }

    return join ( '.', @result );
}

=pod

=head2 computeHostRange($ipaddr, $netmask)

Given a network specification (IP address and netmask), compute
the total number of hosts in that network, as well as the first
and last IP addresses in the range.

=cut

sub computeHostRange ($$)
{
    my ( $ipaddr, $netmask ) = @_;

    my $ipaddrBits   = IPquadToAddr($ipaddr);
    my $netmaskBits  = IPquadToAddr($netmask);
    my $hostmaskBits = ( ( ~$netmaskBits ) & 0xffffffff );

    my $firstAddrBits = $ipaddrBits & $netmaskBits;
    my $lastAddrBits  = $ipaddrBits | $hostmaskBits;

    my $totalHosts = 1;

    for ( ; $hostmaskBits ; $hostmaskBits /= 2 )
    {
        if ( ( $hostmaskBits & 0x1 ) == 0x1 )
        {
            $totalHosts *= 2;
        }
    }

    return ( $totalHosts, IPaddrToQuad($firstAddrBits),
        IPaddrToQuad($lastAddrBits) );
}

=pod

=head2 ldapBase($domain)

Given a domain name such as foo.bar.com, generate the
LDAP base name "dc=foo,dc=bar,dc=com".

=cut

sub ldapBase ($)
{
    my ($domainName) = @_;
    $domainName =~ s/\./,dc=/g;
    return "dc=" . $domainName;
}

=pod

=head2 backgroundCommand($delaySec, @command)

Run command in background after a specified delay.

=cut

sub backgroundCommand ($@)
{
    my ( $delaySec, @command ) = @_;

    # now would be a good time to flush output buffers, so the partial
    # buffers don't get copied

    $| = 1;
    print "";

    # create child process
    my $pid = fork;

    # if fork failed, bail out
    die "Cannot fork: $!" unless defined($pid);

    # If fork succeeded, make parent process return immediately.
    # We are not waiting on the child, so it will become a zombie
    # process when it completes. However, this subroutine is only
    # intended for use by the e-smith signal-event program, which
    # doesn't run very long. Once the parent terminates, the zombie
    # will become owned by "init" and will be reaped automatically.

    return if ($pid);

    # detach ourselves from the terminal
    setsid || die "Cannot start a new session: $!";

    # change working directory
    chdir "/";

    # clear file creation mask
    umask 0;

    # close STDIN, STDOUT, and STDERR
    close STDIN;
    close STDOUT;
    close STDERR;

    # reopen stderr, stdout, stdin
    open( STDIN, '/dev/null' );

    my $loggerPid = open( STDOUT, "|-" );
    die "Can't fork: $!\n" unless defined $loggerPid;

    unless ($loggerPid)
    {
        exec qw(/usr/bin/logger -p local1.info -t e-smith-bg);
    }

    open( STDERR, '>&STDOUT' );

    # make child wait for specified delay.
    sleep $delaySec;

    # execute command
    exec { $command[0] } @command or warn "Can't @command : $!\n";   
}

=pod

=head1 PASSWORD UTILITIES

Low-level password-changing utilities. These utilities each
change passwords for a single underlying password database,
for example /etc/passwd, /etc/samba/smbpasswd, etc.

=head2 validatePassword($password, $strength)

Validate Unix password.
length is the minimal password length, default is 12.
strength could be none,normal,intermediate or strong.
- none 		The password can be anything as no checking is done other than the minimum length of characters. (default 12)
- normal 	The password requires at least 1 upper (A-Z), 1 lower (a-z) on top of the none setting checks.
- intermediate 	The password requires to pass a Cracklib dictionary check on top of the normal setting checks.
- strong 	The password requires to have at least 1 digit (0-9) and 1 special character (/-?) on top of the intermediate setting checks. 

=cut

sub validatePassword($$)
{
    my ( $password, $strength ) = @_;
    use Crypt::Cracklib;

    $strength ||= 'normal';

    my $length = 12;
    my $db = esmith::ConfigDB->open() || undef;
    my $sysconfig = $db->get("passwordstrength")||  undef  if $db ;
    $length = $sysconfig->prop("length") || "12" if $sysconfig;

    my $reason = 'ok';
    $reason = 'it is too short' unless (length($password) >= $length);
    return $reason if ($reason ne 'ok' || $strength eq 'none');

    $reason = 'it does not contain uppercase characters' if (not $password =~ /[A-Z]/);
    $reason = 'it does not contain lowercase characters' if (not $password =~ /[a-z]/);
    return $reason if ($reason ne 'ok' || $strength eq 'normal');

    # we are left here with intermediate and strong
    if ($strength eq 'strong') {
        $reason = 'it does not contain numbers' if (not $password =~ /\d/);
        $reason = 'it does not contain special characters' if (not $password =~ /\W|_/);
    }
    return $reason if ($reason ne 'ok' && $strength eq 'strong');

    if ( -f '/usr/lib64/cracklib_dict.pwd' ) {
        $reason = fascist_check($password, '/usr/lib64/cracklib_dict');
    } else {
        $reason = fascist_check($password, '/usr/lib/cracklib_dict');
    }
    $reason ||= 'the password check failed';

    return 'ok' if (lc($reason) eq 'ok');
    return $reason;
}

=pod

=head2 setUnixPassword($username, $password)

Set Unix password

=cut

sub setUnixPassword($$)
{
    my ( $username, $password ) = @_;
    setUnixPasswordRequirePrevious( $username, undef, $password );
}

=pod

=head2 authenticateUnixPassword ($username, $password)

Check if the given username/password pair is correct.  
Return 1 if they are correct, return 0 otherwise.

=cut

sub authenticateUnixPassword ($$)
{
    my ( $username, $password ) = @_;

    my $pam_auth_func = sub {
        return ( PAM_SUCCESS(), $password, PAM_SUCCESS() );
    };
    my $pamh = new Authen::PAM( 'passwd', $username, $pam_auth_func );

    unless ( ref($pamh) )
    {
        warn "WARN: Couldn't open Authen::PAM handle for user $username";
        return 0;
    }
    my $res = $pamh->pam_authenticate();
    return ( $res == PAM_SUCCESS() ) || 0;
}

=pod

=head2 setUnixPasswordRequirePrevious($username, $oldpassword, $newpassword)

Set Unix password but require previous password for authentication.

=cut

# setUnixPasswordRequirePrevious is left as an exercise for the reader :-)
sub setUnixPasswordRequirePrevious ($$$)
{
    my ( $username, $oldpassword, $newpassword ) = @_;
    use Authen::PAM;
    my $state;

    my $my_conv_func = sub {
        my @res;
        while (@_)
        {
            my $code = shift;
            my $msg  = shift;
            my $ans  = "";

            $ans = $username if ( $code == PAM_PROMPT_ECHO_ON() );
            if ( $code == PAM_PROMPT_ECHO_OFF() )
            {
                if ( $< == 0 || $state >= 1 )
                {
                    # are we asked for a new password
                    $ans = $newpassword;
                }
                else
                {
                    # asked for old password before we can set a new one.
                    $ans = $oldpassword;
                }
                $state++;
            }

           #print("code is $code, ans is $ans, msg is $msg, state is $state\n");
            push @res, ( PAM_SUCCESS(), $ans );
        }
        push @res, PAM_SUCCESS();
        return @res;
    };

    my $pamh = new Authen::PAM( "passwd", $username, $my_conv_func );
    unless ( ref($pamh) )
    {
        warn "Autopasswd: error code $pamh during PAM init!";
        warn "Failed to set Unix password for account $username.\n";
        return 0;
    }

    # Require the old password to be correct before proceeding to set a new
    # one.
    # This does that, except if you're already root, such as from the
    # bootstrap-console
    $state = 0;
    unless ( $< == 0 or $pamh->pam_authenticate == 0 )
    {
        warn
"PAM authentication failed for user \"$username\", old password invalid!\n";
        return 0;
    }

    $state = 0;
    my $res = $pamh->pam_chauthtok;
    unless ( $res == PAM_SUCCESS() )
    {
        my $err = $pamh->pam_strerror($res);
        warn "Failed to set Unix password for account $username: $err\n";
        return 0;
    }
    return 1;    # success
}

=pod

=head2 setSambaPassword($username, $password)

Set Samba password

=cut

sub setSambaPassword ($$)
{
    my ( $username, $password ) = @_;

    #----------------------------------------
    # then set the password
    #----------------------------------------

    my $smbPasswdProg = '/usr/bin/smbpasswd';

    # see perldoc perlipc (search for 'Safe Pipe Opens')
    my $pid = open( DISCARD, "|-" );

    if ($pid)    # parent
    {
        print DISCARD "$password\n$password\n";
        close(DISCARD) || die "Child exited early.";
    }
    else         # child
    {
        my $retval = system("$smbPasswdProg -a -s $username >/dev/null");
        ( $retval / 256 )
          && die "Failed to set Samba password for account $username.\n";
        exit 0;
    }
    # Now we enable the account
    return system("$smbPasswdProg -e $username >/dev/null") ? 0 : 1;
}

=pod

=head2 cancelSambaPassword($username)

Cancel Samba password

=cut

sub cancelSambaPassword ($)
{
    my ($username) = @_;

    #----------------------------------------
    # Gordon Rowell <gordonr@e-smith.com> June 7, 2000
    # We really should maintain old users, which would mean we can just use
    # smbpasswd -d, but the current policy is to remove them. If we are
    # doing that (see below), there is no need to disable them first.
    #----------------------------------------
    #    my $discard = `/usr/bin/smbpasswd -d -s $username`;
    #    if ($? != 0)
    #    {
    #   die "Failed to disable Samba account $username.\n";
    #    }

    #----------------------------------------
    # Delete the smbpasswd entry. If we don't, re-adding the same
    # username will result in a mismatch of UIDs between /etc/passwd
    # and /etc/smbpasswd
    #----------------------------------------
    # Michael Brader <mbrader@stoic.com.au> June 2, 2000
    # We have a locking problem here.
    # If two copies of this are run at once you could see your entry reappear
    # Proposed solution (file locking):

    # If we do a 'use Fcntl, we'll probably get the locking constants
    # defined, but for now:

    # NB. hard to test

    my $LOCK_EX = 2;
    my $LOCK_UN = 8;

    my $smbPasswdFile = '/etc/samba/smbpasswd';

    open( RDWR, "+<$smbPasswdFile" ) ||    # +< == fopen(path, "r+",...
      die "Cannot open file $smbPasswdFile: $!\n";

    my $nolock = 1;
    my $attempts;
    for ( $attempts = 1 ; ( $attempts <= 5 && $nolock ) ; $attempts++ )
    {
        if ( flock( RDWR, $LOCK_EX ) )
        {
            $nolock = 0;
        }
        else
        {
            sleep $attempts;
        }
    }

    $nolock && die "Could not get exclusive lock on $smbPasswdFile\n";

    my $outputString = '';
    while (<RDWR>)
    {
        (/^$username:/) || ( $outputString .= $_ );
    }

    # clear file and go to beginning
    truncate( RDWR, 0 ) || die "truncate failed";    # not 'strict' safe why???
    seek( RDWR, 0, 0 ) || die "seek failed";
    print RDWR $outputString;
    flock( RDWR, $LOCK_UN )
      || warn "Couldn't remove exclusive lock on $smbPasswdFile\n";
    close RDWR || die "close failed";

    chmod 0600, $smbPasswdFile;

    return 1;                                        # success
}

=pod

=head2 LdapPassword()

Returns the LDAP password from the file C</etc/openldap/ldap.pw>.
If the file does not exist, a suitable password is created, stored
in the file, then returned to the caller.

Returns undef if the password could not be generated/retrieved.

=cut

sub genLdapPassword ()
{

    # Otherwise generate a suitable new password, store it in the
    # correct file, and return it to the caller.

    use MIME::Base64 qw(encode_base64);

    unless ( open( RANDOM, "/dev/urandom" ) )
    {
        warn "Could not open /dev/urandom: $!";
        return undef;
    }

    my $buf = "not set";

    # 57 bytes is a full line of Base64 coding, and contains
    # 456 bits of randomness - given a perfectly random /dev/urandom
    if ( read( RANDOM, $buf, 57 ) != 57 )
    {
        warn("Short read from /dev/urandom: $!");
        return undef;
    }
    close RANDOM;

    my $umask    = umask 0077;
    my $password = encode_base64($buf, "");

    unless ( open( WR, ">/etc/openldap/ldap.pw" ) )
    {
        warn "Could not write LDAP password file.\n";
        return undef;
    }

    print WR "$password\n";
    close WR;
    umask $umask;

    chmod 0600, "/etc/openldap/ldap.pw";

    return $password;
}

sub LdapPassword ()
{

    # Read the password from the file /etc/openldap/ldap.pw if it
    # exists.
    if ( -f "/etc/openldap/ldap.pw" )
    {
        open( LDAPPW, "</etc/openldap/ldap.pw" )
          || die "Could not open LDAP password file.\n";
        my $password = <LDAPPW>;
        chomp $password;
        close LDAPPW;
        return $password;
    }
    else
    {
        return genLdapPassword();
    }
}

=pod

=head2 set_secret()

Shortcut method to create and set a password property on a record without having to extract the record first.

The password creation is based on an UID of 64 bits (Data::UUID). If the optional type option is passed, 
it will be used to create the record if it does not already exist. Otherwise, a default 'service' type 
will be used to create the record.

The $DB is expected to be an already open esmith::DB object, so that an open DB in the caller can be re-used. 
Therefore in a migrate fragment you could just use $DB.

         esmith::util::set_secret($DB, '$key','$property'[,type=>'$type']);

For example in /etc/e-smith/db/configuration/migrate/90roundcube
     {
         esmith::util::set_secret($DB, 'foo','DbPassword',type=>'service');
     }

The password will be generated to the property 'DbPassword' in the 'foo' key.

If you want to change the database then you must open another esmith::DB objet
     {
         my $database = esmith::ConfigDB->open('accounts') or
                die esmith::DB->error;
         esmith::util::set_secret($database, 'foo','DbPassword',type=>'user');
     }

=cut

sub set_secret

{
    my ($db, $key, $prop, %options) = @_;
    %options = (type => 'service', %options);

    my $record = $db->get($key) ||
                 $db->new_record($key, \%options) or
                 die "Error creating new record";

    return if $db->get_prop($key,$prop);

    $record->merge_props(%options, $prop =>
       Data::UUID->new->create_b64());
}



=pod

=head1 HIGH LEVEL PASSWORD UTILITIES

High-level password-changing utilities. These utilities
each change passwords for a single e-smith entity (system,
user or ibay). Each one works by calling the appropriate
low-level password changing utilities.

=head2 setUnixSystemPassword($password)

Set the e-smith system password

=cut

sub setUnixSystemPassword ($)
{
    my ($password) = @_;

    setUnixPassword( "root",  $password );
    setUnixPassword( "admin", $password );
}

=pod

=head2 setServerSystemPassword($password)

Set the samba administrator password.

=cut

sub setServerSystemPassword ($)
{
    my ($password) = @_;

    setSambaPassword( "admin", $password );
}

=pod

=head2 setUserPassword($username, $password)

Set e-smith user password

=cut

sub setUserPassword ($$)
{
    my ( $username, $password ) = @_;

    setUnixPassword( $username, $password );
    setSambaPassword( $username, $password );
}

=pod

=head2 setUserPasswordRequirePrevious($username, $oldpassword, $newpassword)

Set e-smith user password - require previous password

=cut

sub setUserPasswordRequirePrevious ($$$)
{
    my ( $username, $oldpassword, $newpassword ) = @_;

    # We need to suid to the user, instead of root, so that PAM will
    # prompt us for the old password.
    my @pwent = getpwnam($username);
    return 0 unless ( $pwent[2] > 0 );    # uid must be non-zero
    my $uid = $<;
    $< = $pwent[2];

    # Return if this function call fails, we didn't change passwords
    # successfully.
    my $ret =
      setUnixPasswordRequirePrevious( $username, $oldpassword, $newpassword );
    $< = $uid;
    return 0 unless $ret;

    # if we get this far, the old password must have been valid
    setSambaPassword( $username, $newpassword );
}

=pod

=head2 cancelUserPassword

Cancel user password. This is called when a user is deleted from the
system. We assume that the Unix "useradd/userdel" programs are
called separately. Since "userdel" automatically removes the
/etc/passwd entry, we only need to worry about the /etc/samba/smbpasswd
entry.

=cut

sub cancelUserPassword ($)
{
    my ($username) = @_;

    cancelSambaPassword($username);
}

=pod

=head2 setIbayPassword($ibayname, $password)

Set ibay password

=cut

sub setIbayPassword ($$)
{
    my ( $ibayname, $password ) = @_;

    setUnixPassword( $ibayname, $password );
}

=pod

=head1 SERVICE MANAGEMENT UTILITIES

=head2 serviceControl()

Manage services - stop/start/restart/reload/graceful

Returns 1 for success, 0 if something went wrong, fatal exception on bad
arguments.

    serviceControl(
        NAME=>serviceName,
        ACTION=>start|stop|restart|reload|graceful
        [ BACKGROUND=>true|false (default is false) ]
    );

EXAMPLE:

    serviceControl( NAME=>'httpd-e-smith', ACTION=>'reload' );

NOTES:

The BACKGROUND parameter is optional and can be set to true if
start/stop/restart/etc. is to be done in the background (with
backgroundCommand()) rather than synchronously.

CONVENTIONS:

This command is the supported method for action scripts, blade handlers, etc.,
to start/stop/restart their services. Currently this is done via the rc7
symlinks, but this may change one day. Using this function gives us one
location to change this behaviour if desired, instead of hunting all over
every scrap of code. Please use it.

=cut

sub serviceControl
{
    my %params = @_;

    my $serviceName = $params{NAME};
    unless ( defined $serviceName )
    {
        die "serviceControl: NAME must be specified";
    }

    my $serviceAction = $params{ACTION};
    unless (defined $serviceAction)
    {
        die "serviceControl: ACTION must be specified";
    }

    if ( $serviceAction =~ /^(start|stop|restart|reload|graceful|adjust|svdisable|reload-or-restart|try-restart|reload-or-try-restart|enable -now|enable|disable|sig[A-Za-z12]+)$/ )
    {
        my ($startScript) = glob("/etc/rc.d/rc7.d/S*$serviceName") ||'' ;
        my ($systemdScript) = "/usr/lib/systemd/system/$serviceName.service" ||'';
        my ($systemdAlias) = "/etc/systemd/system/$serviceName.service" ||'';
        my $multiple = "$serviceName.service";
        ($multiple = $serviceName ) =~ s/([a-zA-Z0-9\-_.]+@)(.*)/$1.service/ if ( $serviceName =~ /@/ );

        # Prevent issues during gui update. 
        # Any smanager restart will kill children and as result the update process.
        # Hard restart of httpd-e-smith will likely timeout the browser.
        $serviceAction = "reload-or-restart" if ( ($serviceAction eq "restart") and  ( $serviceName eq "smanager" or $serviceName eq "httpd-e-smith"));

        unless ( -e $startScript or -e $systemdScript or -e "/usr/lib/systemd/system/$multiple" or -e $systemdAlias)
        {
            warn "serviceControl: startScript not found "
              . "for service $serviceName\n";
            return 0;
        }

        if ( (-e $systemdScript  or -e "/usr/lib/systemd/system/$multiple" or -e $systemdAlias) and ! -e $startScript)
        {
            # systemd is not aware of adjust, sigusr1, sigusr2, sigterm, sighup
            $serviceAction = ( $serviceAction =~/^(adjust|graceful|sighup|sigusr1|sigusr2)$/ ) ? "reload-or-restart" : $serviceAction; 
            $serviceAction = ( $serviceAction eq "sigterm" ) ? "restart" : $serviceAction;
            if ($serviceAction =~/^(sig[A-Za-z12]+)$/) 
            {
                $serviceAction=uc($serviceAction);
                system('/usr/bin/systemctl',"kill","--signal=$serviceAction","$serviceName.service") == '0'
                ||    warn "serviceControl: Couldn't " .
                "system( /usr/bin/systemctl kill --signal=$serviceAction $serviceName.service): $!\n";
            }
            elsif ($serviceAction =~/^(start|stop|restart|reload|reload-or-restart|try-restart|reload-or-try-restart|enable -now|enable|disable)$/) 
            {
                system('/usr/bin/systemctl',"$serviceAction","$serviceName.service") == '0'
                ||    warn "serviceControl: Couldn't " .
                "system( /usr/bin/systemctl $serviceAction $serviceName.service): $!\n";
            }
            else 
            {
                die "serviceControl: systemd doesn't know : systemctl $serviceAction $serviceName.service";
            }
        }
        elsif (-e $startScript) 
        {
            my  $background = $params{'BACKGROUND'} || 'false';

            die "serviceControl: Unknown serviceAction $serviceAction" if ($serviceAction =~/^(reload-or-restart|try-restart|reload-or-try-restart|enable -now|enable|disable)$/);
            if ( $background eq 'true' )
            {
            backgroundCommand( 0, $startScript, $serviceAction );
            }
            elsif ( $background eq 'false' )
            {
                unless ( system( $startScript, $serviceAction ) == 0 )
                {
                warn "serviceControl: "
                  . "Couldn't system($startScript, $serviceAction): $!\n";
                return 0;
                }
           }
           else
           {
            die "serviceControl: Unsupported BACKGROUND=>$background";
           }
        }
    }
    else
    {
        die "serviceControl: Unknown serviceAction $serviceAction";
    }
    return 1;
}

=head2 getLicenses()

Return all available licenses

In scalar context, returns one string combining all licenses
In array context, returns an array of individual licenses

Optionally takes a language tag to be used for retrieving the licenses,
defaulting to the locale of the server.

=for testing
$ENV{ESMITH_LICENSE_DIR} = "10e-smith-lib/licenses";
ok(-d $ENV{ESMITH_LICENSE_DIR}, "License dir for testing exists");
like($l = esmith::util::getLicenses("fr_CA"), qr/Je suis/, "Found french license");
like($l = esmith::util::getLicenses("en_US"), qr/I am/,    "Found english license");

=cut

sub getLicenses
{
    my ($locale) = @_;

    if ($locale)
    {
        $locale =~ s/-(\S\S)/_\U$1/;
    }
    else
    {
        my $db = esmith::ConfigDB->open();

        my ( $lang, @rest ) = $db->getLocale();

        $lang = $lang || "en_US";

        $locale = $lang;
    }

    my $base_dir = $ENV{ESMITH_LICENSE_DIR} || "/etc/e-smith/licenses";

    $locale = "en_US" unless ( -d "${base_dir}/${locale}" );

    my $dir = "${base_dir}/${locale}";

    my @licenses;

    opendir( DIR, $dir ) || die "Couldn't open licenses directory\n";

    foreach my $license ( readdir(DIR) )
    {
        my $file = "${dir}/${license}";

        next unless ( -f $file );

        open( LICENSE, $file ) || die "Couldn't open license $file\n";

        push @licenses, <LICENSE>;

        close LICENSE;
    }

    return wantarray ? @licenses : "@licenses";
}

=head2 getLicenseFile()

Return the license filename.

Optionally takes a language tag to be used for retrieving the license,
defaulting to the locale of the server.

If more than one license file than return the first alphabetically.

=cut

sub getLicenseFile
{
    my ($locale) = @_;

    if ($locale)
    {
        $locale =~ s/-(\S\S)/_\U$1/s;
    }
    else
    {
        my $db = esmith::ConfigDB->open();

        my ( $lang, @rest ) = $db->getLocale();

        $lang = $lang || 'en_US';

        $locale = $lang;
    }

    my $base_dir = $ENV{ESMITH_LICENSE_DIR} || '/etc/e-smith/licenses';

    $locale = 'en_US' unless ( -d "${base_dir}/${locale}" );

    my $dir = "${base_dir}/${locale}";

    opendir( DIR, $dir ) || die "Couldn't open licenses directory\n";

    my @licenses;
    foreach my $license ( readdir DIR )
    {
        untaint ($license);
        my $file = "${dir}/${license}";
        next unless ( -f $file );
        push @licenses, $file;
    }

    @licenses = sort @licenses;

    return shift @licenses;
}


=item B<initialize_default_databases>

Initialize all databases located at /etc/e-smith/db.

=cut

sub initialize_default_databases
{

    # Optionally take an argument to the db root, for testing purposes.
    my %defaults = (
        dbroot => '/etc/e-smith/db',
        dbhome => '/home/e-smith/db',
        old_dbhome => '/home/e-smith',
    );
    my %args   = ( %defaults, @_ );
    my $dbroot = $args{dbroot};
    my $dbhome = $args{dbhome};
    my $old_dbhome = $args{old_dbhome};

    local *DH;
    opendir DH, $dbroot
      or die "Could not open $dbroot: $!";

    my @dirs = readdir(DH);

    # Move all databases to new home first them migrate data
    # Untaint db names while we are at it.
    foreach my $file ( map { /(.+)/ ; $1 } grep !/^\./, @dirs )
    {
        if (-f "${old_dbhome}/$file")
        {
            if (-l "${old_dbhome}/$file")
            {
                warn "symlink called ${old_dbhome}/$file exists\n";
		next;
            }

            if (-s "${dbhome}/$file")
            {
                warn "${old_dbhome}/$file and ${dbhome}/$file exist\n";
                rename "${dbhome}/$file", "${dbhome}/$file." . time;
            }

	    warn "Rename ${old_dbhome}/$file => ${dbhome}/$file\n";
	    rename "${old_dbhome}/$file", "${dbhome}/$file";
        }
    }

    foreach my $file ( grep !/^\./, @dirs )
    {
        # Untaint the result of readdir. As we're expecting filenames like
        # 'configuration' and 'ipphones', lets restrict input to those.
        if ($file =~ /(^[A-Za-z0-9_\.-]+$)/)
        {
            $file = $1;
        }
        else
        {
	    warn "Not processing unexpected file $file\n";
            next;
        }

        eval
        {
            my $h = esmith::ConfigDB->open($file);
            if ($h)
            {
                warn "Migrating existing database $file\n";

                # Convert old data to new format, and add any new defaults. Note
                # that migrate returns FALSE on fatal errors. Report those to
                # syslog. The error should still be in $@.
                unless ( $h->migrate() )
                {
                    warn "Migration of db $file failed: " . esmith::DB->error;
                }
            }
            else
            {
                warn "Creating database $file and setting defaults\n";

                # create() and load defaults
                unless ( $h = esmith::ConfigDB->create($file) )
                {
                    warn "Could not create $file db: " . esmith::DB->error;
                }
            }

            $h->close;

            esmith::util::chownFile( "root", "admin", "$dbhome/$file" );
        };
        if ($@)
        {
            warn "Fatal error while processing db $file: $@\n";
        }
    }
    return 1;
}


=head1 AUTHOR

Mitel Networks Corp.

For more information, see http://www.e-smith.org/

=cut

1;
