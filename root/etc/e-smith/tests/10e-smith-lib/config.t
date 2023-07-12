#!/usr/bin/perl -w

# Overall tests for esmith::config

use strict;
use File::Copy;

use Test::More 'no_plan';
use_ok('esmith::config');

my %Expect = ( foo              => 'bar',
               'this key'       => 'has whitespace',
               'that key '      => 'has trailing whitespace',
               ' another key'   => 'has leading whitespace',
               'this value'     => ' has leading whitespace',
               'that value'     => 'has trailing whitespace ',
               'tricky value'   => 'with=equals.',
             );


# so we don't bork the original.
my $Scratch = '10e-smith-lib/mydummy.conf';
copy('10e-smith-lib/dummy.conf', $Scratch);
END { unlink $Scratch }

my %config;
tie %config, 'esmith::config', $Scratch;
ok( tied %config,                'tie worked' );
is_deeply( \%config, \%Expect,   'read in the config properly' );

# Test the tied interface.
is_deeply( [sort keys   %config], [sort keys   %Expect], 'keys' );
is_deeply( [sort values %config], [sort values %Expect], 'values' );

is_deeply( [@config{'foo', 'this key'}], [@Expect{'foo', 'this key'}],
                                                           'hash slice');

$config{foo} = 'baz';
is( $config{foo}, 'baz',        'STORE' );

my %config_copy;
tie %config_copy, 'esmith::config', $Scratch;
is( $config_copy{foo}, 'baz',   '  STORE saved' );

SKIP: {
   skip "Locking is broken in perl 5.6.0", 2 if $] eq 5.006;

tied(%config_copy)->_lock_write;
my $start_time = time;
{
    local $ENV{PERL5LIB} = join ':', @INC;
    system(qq{$^X -Mesmith::config -e 'alarm 4;  tie %config, "esmith::config", q{$Scratch}'});
}

cmp_ok( time - 2, '<=', $start_time,     'write locks dont prevent read' );


tied(%config_copy)->_lock_write;
$start_time = time;
{
    local $ENV{PERL5LIB} = join ':', @INC;
    system(qq{$^X -Mesmith::config -e 'alarm 4;  tie %config, "esmith::config", q{$Scratch};  \$config{foo} = 42'});
}

cmp_ok( time - 1, '>=', $start_time,     'write locks prevent writes' );
};

my $new_conf = 'I_dont_exist';
unlink $new_conf;
ok( !-e $new_conf,  'config file doesnt exist' );
END { unlink $new_conf }

tie %config, 'esmith::config', $new_conf;
is( keys %config, 0, 'new() from nonexistent config' );
$config{wibble} = 'wobble';

tie %config_copy, 'esmith::config', $new_conf;
is( $config_copy{wibble}, 'wobble',   '  new config file written' );


SKIP: {
   skip "Locking is broken in perl 5.6.0", 1 if $] eq 5.006;

# There was a bug where if you set something to its existing value
# it wouldn't unlock properly.
my $Alarm;
eval {
    local $SIG{ALRM} = sub { $Alarm = 1;  die "ALARM!\n"; };
    alarm 1;
    $config_copy{wibble} = $config_copy{wibble};
    $config{wibble} = 42;
    alarm 0;
};
ok( !$Alarm, 'Unlocking works for setting the same value' );
};
