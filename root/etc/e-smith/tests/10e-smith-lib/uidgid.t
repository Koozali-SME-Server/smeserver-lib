#!/usr/bin/perl -w
# vim: ft=perl:

use strict;
use Test::More 'no_plan';
use Unix::PasswdFile;
use Unix::GroupFile;

use constant TRUE  => 1;
use constant FALSE => 0;

my $conffile = 'uidgid.conf';

exit 1 if not -e $conffile;

my %passwdlist = ();
my %grouplist  = ();
my $passwd = FALSE;
my $group = FALSE;

open(CONF, "<$conffile") or die "Can't open $conffile: $!\n";

while(<CONF>)
{
    next if /^(#|\s)/;
    if (/\[passwd]/)
    {
	$passwd = TRUE;
	next;
    }
    elsif (/\[group]/)
    {
	$group = TRUE;
	$passwd = FALSE;
	next;
    }
    next if not $passwd and not $group;

    if ($passwd)
    {
	my ($uid, $name, $gid) = split;
	$passwdlist{$name}{uid} = $uid;
	$passwdlist{$name}{gid} = $gid;
    }
    elsif ($group)
    {
	my ($gid, $name) = split;
	$grouplist{$name} = $gid;
    }
}
close(CONF);

# We can now confirm the uid and gid of every user, and the gid of every
# group, on the system.
# I don't know of a good way to query every user on the system, so for now
# lets just read them from the passwd file.
my $pw = Unix::PasswdFile->new('/etc/passwd', mode => 'r')
	or die "Can't open /etc/passwd: $!\n";

foreach my $user ($pw->users)
{
    my ($name,$passwd,$uid,$gid,undef) = getpwnam($user);
    ok( exists $passwdlist{$name}, "user $name is on our list" );
    ok( $uid == $passwdlist{$name}{uid}, "user $name has uid of $uid" );
    ok( $gid == $passwdlist{$name}{gid}, "user $name has gid of $gid" );
}

my $gr = Unix::GroupFile->new('/etc/group', mode => 'r')
	or die "Can't open /etc/group: $!\n";

foreach my $group ($gr->groups)
{
    my ($name,$passwd,$gid,$members) = getgrnam($group);
    ok( exists $grouplist{$name}, "group $name is on our list" );
    ok( $gid == $grouplist{$name}, "group $group has gid of $gid" );
}

exit 0;
