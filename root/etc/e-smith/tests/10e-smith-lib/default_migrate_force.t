#!/usr/bin/perl -w
# vim: ft=perl:

use strict;
use esmith::util;
use esmith::ConfigDB;
use Test::More 'no_plan';
use File::Copy qw(copy);
use POSIX qw(tmpnam);

# What we want to do is run initialize-default-databases on a scratch
# db and check the results.
my $dbhome = '/tmp/dbhome';
my $dbroot = '/etc/e-smith/db';
system('rm', '-rf', $dbhome);
system('mkdir', '-p', $dbhome) == 0
    or die "Can't create $dbhome: $!\n";

ok( esmith::util::initialize_default_databases(dbhome => $dbhome),
    "initialize_default_databases created successfully" );

# Confirm the default settings.
walk_dbtree($dbroot, 'defaults');
# Test that forced options were forced.
walk_dbtree($dbroot, 'force');

# We should now have default configuration files. We can go through each
# setting specified by the defaults and confirm that it is correct.

# To test migration, we should take a typical 5.6 set of databases and migrate
# those. The existing .conf databases in the 10e-smith-lib directory are
# styled after 5.6, and suitable for this.
foreach my $dummyconf (qw(accounts.conf domains.conf networks.conf 
                          configuration.conf hosts.conf))
{
    # Copy them over the ones in our test directory, and then migrate them.
    my $dest;
    ($dest = $dummyconf) =~ s/\.conf$//;
    $dest = "$dbhome/$dest";
    copy($dummyconf, $dest) or die "Can't copy $dummyconf to $dest: $!\n";
}

# Migrate the directory.
ok( esmith::util::initialize_default_databases(dbhome => $dbhome),
    "initialize_default_databases migrated successfully" );

#run_migrate_tests($dbhome, $dbroot);
system('rm', '-rf', $dbhome);

exit 0;

sub walk_dbtree
{
    my $dbroot = shift;
    my $mode = shift;
    die unless $mode =~ /^(defaults|force)$/;

    opendir(DBROOT, $dbroot) or die "Can't open $dbroot: $!\n";
    my @dbfiles = grep { -d "$dbroot/$_" }
		grep { !/^\./ } readdir DBROOT;
    closedir(DBROOT);
    foreach my $dbfile (@dbfiles)
    {
	# Handle the defaults in this case.
	my $defaultdir = "$dbroot/$dbfile/defaults";
	next if not -e $defaultdir;
	opendir(DEFAULTDIR, $defaultdir) or die "Can't open $defaultdir: $!\n";
	my @keys = grep { -d "$defaultdir/$_" }
		grep { !/^\./ } readdir DEFAULTDIR;
	closedir(DEFAULTDIR);
	# There should now be a db file output at the dbhome.
	ok( -e "$dbhome/$dbfile", "$dbfile db exists" );

	my $db = esmith::ConfigDB->open_ro("$dbhome/$dbfile");
	ok( defined $db, "$dbhome/$dbfile loads properly" );
	# Loop on all the keys.
	foreach my $keydir (@keys)
	{
	    my $key_fullpath = "$defaultdir/$keydir";
	    opendir(KEYDIR, $key_fullpath)
		or die "Can't open $key_fullpath: $!\n";
	    my @propfiles = grep { -f "$key_fullpath/$_" }
			    grep { !/^\./ } readdir KEYDIR;
	    closedir(KEYDIR);

	    foreach my $propfile (@propfiles)
	    {
		my $propfile_fullpath = "$key_fullpath/$propfile";
		# Open each and check what the default should be.
		open(PROPFILE, "<$propfile_fullpath")
		    or die "Can't open $propfile_fullpath: $!\n";
		chomp( my $propval = <PROPFILE> );
		close(PROPFILE);
		if ($keydir eq 'ActiveAccounts')
		{
		    print "get_prop on $keydir, $propfile returns ";
		    print $db->get_prop($keydir, $propfile) . "\n";
		    print "propval is $propval\n";
		}
		ok( $db->get_prop($keydir, $propfile) eq $propval,
		    "property $propfile of record $keydir has correct $mode value of $propval" );
	    }
	}
    }
}

# FIXME: This works, but the numbers of the tests are thrown off. We probably
# want to eval the test block of code instead.
sub run_migrate_tests
{
    my $dbhome = shift;
    my $dbroot = shift;

    opendir(DBROOT, $dbroot) or die "Can't open $dbroot: $!\n";
    my @dbfiles = grep { -d "$dbroot/$_" }
		grep { !/^\./ } readdir DBROOT;
    closedir(DBROOT);
    foreach my $dbfile (@dbfiles)
    {
	# Handle the defaults in this case.
	my $migratedir = "$dbroot/$dbfile/migrate";
	next if not -e $migratedir;

	opendir(MIGRATEDIR, $migratedir) or die "Can't open $migratedir: $!\n";
	my @migrate_fragments = grep { !/^\./ } readdir MIGRATEDIR;
	closedir(MIGRATEDIR);

	foreach my $migrate_fragment (sort @migrate_fragments)
	{
	    my $tempname = tmpnam() or die "Can't obtain tempfile: $!\n";
	    my $pod2test = '/usr/bin/pod2test';
	    system($pod2test, "$migratedir/$migrate_fragment", $tempname);
	    if (! -e $tempname)
	    {
		warn "The fragment $migrate_fragment apparently has no embedded tests\n";
		next;
	    }
	    system('/usr/bin/perl', $tempname);
	}
    }
}
