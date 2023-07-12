#!/usr/bin/perl -w

use esmith::TestUtils qw(scratch_copy);
use File::Path;

use Test::More 'no_plan';

use_ok('esmith::templates', qw(:DEFAULT removeBlankLines));

use esmith::config;
my %config;
tie %config, 'esmith::config', '10e-smith-lib/scratch.conf';
$ENV{ESMITH_CONFIG_DB} = '10e-smith-lib/scratch.conf';
END { unlink '10e-smith-lib/scratch.conf' }

my $Scratch_Temp_Dir = 'template_scratch_dir';
my $Scratch_Temp = "$Scratch_Temp_Dir/dummy";
mkpath "$Scratch_Temp_Dir/10e-smith-lib";
END { rmtree $Scratch_Temp_Dir }

# processTemplate() is going to be Loud and Helpful about skipping
# things like CVS directories.
$SIG{__WARN__} = sub { return if $_[0] =~ /^Skipping directory/ };

$config{Koala_Say} = "This is not the bear you're looking for.";
processTemplate({ CONFREF => \%config, 
                  OUTPUT_PREFIX   => $Scratch_Temp_Dir,
                  OUTPUT_FILENAME => 'dummy',
                  TEMPLATE_PATH => 'templates',
                  TEMPLATE_EXPAND_QUEUE => [
                      '10e-smith-lib'
                  ],
                  FILTER => \&removeBlankLines,
                  UID => $<,
                  GID => (split / /, $()[0]
                });

ok( -f $Scratch_Temp,   'file generated' );
ok( -s $Scratch_Temp,   '  its not empty' );

open(SCRATCH, $Scratch_Temp) || die $!;
my $out;
{ local $/; $out = <SCRATCH>; }
close SCRATCH;

my $koala_output = <<'THIS';
# This is the beginning of the beginning
# confref ok
  ----------------------------------------
< This is not the bear you're looking for. >
  ----------------------------------------
  \
   \          .
       ___   //
     {~._.~}// 
      ( Y )K/  
     ()~*~()   
     (_)-(_)   
     Luke    
     Skywalker
     koala   
# This is the end, My only friend, the end of our elaborate templates, the end
THIS

is( $out, $koala_output,   'file generated properly' );

$out = processTemplate({ 
                  CONFREF => \%config, 
                  TEMPLATE_PATH => 'templates',
                  TEMPLATE_EXPAND_QUEUE => [
                      '10e-smith-lib'
                  ],
                  FILTER => sub { $_[0] =~ /^\s*$/ ? '' : $_[0] },
                  UID => $<,
                  GID => (split / /, $()[0],
                  OUTPUT_TYPE => 'string'
                });

is( $out, $koala_output,   'string generated properly' );

my $h_scratch = scratch_copy('10e-smith-lib/hosts.conf');
my $a_scratch = scratch_copy('10e-smith-lib/accounts.conf');
use esmith::AccountsDB;
use esmith::HostsDB;
my $acct = esmith::AccountsDB->open($a_scratch);
my $host = esmith::HostsDB->open($h_scratch);
$out = processTemplate({
                  MORE_DATA => { Author => 'Douglas Adams' },
                  TEMPLATE_PATH => 'templates_DB',
                  TEMPLATE_EXPAND_QUEUE => [
                      '10e-smith-lib'
                  ],
                  OUTPUT_TYPE => 'string'
                });
is( $out, <<'THIS', 'DB & MORE_DATA' );
                        Chapter 1

The story so far:

        In the beginning the Universe was created.  This has made a lot
of people very angry and been widely regarded as a bad move.
                -- Douglas Adams

$DB ok
default vars ok

confref not defined

The end of labor is to gain leisure.
THIS

