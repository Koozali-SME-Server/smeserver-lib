#!/usr/bin/perl -Tw

use strict;
use esmith::config;
use Test::More tests => 2;

my %config;
tie %config, 'esmith::config', '10e-smith-lib/dummy.conf';
my $value = $config{foo};

# Config values *should* be tained, but code depends on them not being.
is( $value, 'bar',      'tied to the dummy database' );
ok( eval { () = join('', $value), kill 0; 1; }, 'config values not tainted' );
