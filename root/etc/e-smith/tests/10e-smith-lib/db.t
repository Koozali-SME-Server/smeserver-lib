#!/usr/bin/perl -w

# Overall test for esmith::db

use File::Copy;
use esmith::TestUtils;
use Test::More 'no_plan';
use_ok('esmith::db');

my %Expect = (
              Foo       =>  ['Bar', {}],
              Night     =>  ['Day', {}],
              Squid     =>  ['cephalopod', {
                                            arms => 10, 
                                            species => 'Loligo',
                                           }
                            ],

              # Ensure that empty values are read in properly.
              Octopus   =>  ['cephalopod', {
                                            arms => 8,
                                            species => '',
                                           }
                            ],

              # Ensure that escaped pipes are read in properly.
              Pipe      =>  ['art',  { pipe => 'this is not a \| got that?'}],

              # Ensure that escaped newlines are handled properly.
              Haiku     =>  ['poem', { words => 
                                       "Damian Conway\n".
                                       "God damn! Damian Conway\n".
                                       "Damian Conway"
                                     }
                            ]
             );

my $Scratch_Conf = '10e-smith-lib/db_scratch.conf';
copy '10e-smith-lib/db_dummy.conf', $Scratch_Conf;
END { unlink $Scratch_Conf }

my %config;
tie %config, 'esmith::config', $Scratch_Conf;
ok( tied %config, 'tied to the dummy config file' );
isnt( keys %config, 0, '  and theres something in there' );

is( db_get_type(\%config, 'Foo'), 'Bar', 'simple db_get_type' );

my @keys = db_get(\%config);
is_deeply( [sort @keys], [sort keys %Expect], 
                                          'db_get() all keys' );


foreach my $key (@keys) {
    my($type, %properties) = db_get(\%config, $key);
    my($exp_type, $exp_properties) = @{$Expect{$key}};

    is( $type, $exp_type,                       "db_get - type - $key" );
    is( db_get_type(\%config, $key), $exp_type, "db_get_type" );
    is_deeply( \%properties, $exp_properties,   "db_get - prop" );
    is_deeply( {db_get_prop(\%config, $key)}, $exp_properties,
                                             "db_get_prop - all properties");
    while( my($prop, $val) = each %properties ) {
        is( db_get_prop(\%config, $key, $prop), $val,
                                   "db_get_prop - single prop - $prop");
    }
}


is( db_get_type(\%config, 'I_dont_exist'), undef,
                                        'db_get_type on non-existent key' );
is( db_get_prop(\%config, 'I_dont_exist'), undef,
                                        '  db_get_prop' );
is( db_get_prop(\%config, 'Squid', 'feet'), undef,
                                        'db_get_prop on non-existent prop' );
is( db_delete_prop(\%config, 'I_dont_exist', 'feet'), undef,
                                      'db_delete_prop on non-existent key' );

is( db_get(\%config, 'Squid'), 'cephalopod|arms|10|species|Loligo',
                                        'db_get a raw value');

{
    package TieOut;

    sub TIEHANDLE {
	bless( \(my $scalar), $_[0]);
    }

    sub PRINT {
	my $self = shift;
	$$self .= join('', @_);
    }

    sub read {
	my $self = shift;
	return substr($$self, 0, length($$self), '');
    }
}

my $out = tie *STDOUT, 'TieOut';
db_show(\%config);
is( $out->read, <<SHOW, 'db_show() all' );
Foo=Bar
Haiku=poem
    words=Damian Conway\nGod damn! Damian Conway\nDamian Conway
Night=Day
Octopus=cephalopod
    arms=8
    species=
Pipe=art
    pipe=this is not a \\| got that?
Squid=cephalopod
    arms=10
    species=Loligo
SHOW

db_show(\%config, 'Squid');
is( $out->read, <<SHOW,       'db_show() one key' );
Squid=cephalopod
    arms=10
    species=Loligo
SHOW


db_print(\%config);
is( $out->read, <<PRINT, 'db_print all' );
Foo=Bar
Haiku=poem|words|Damian Conway\nGod damn! Damian Conway\nDamian Conway
Night=Day
Octopus=cephalopod|arms|8|species|
Pipe=art|pipe|this is not a \\| got that?
Squid=cephalopod|arms|10|species|Loligo
PRINT


db_print(\%config, 'Squid');
is( $out->read, <<PRINT, 'db_print one key' );
Squid=cephalopod|arms|10|species|Loligo
PRINT


db_print_type(\%config);
is( $out->read, <<PRINT_TYPE, 'db_print_type all keys' );
Foo=Bar
Haiku=poem
Night=Day
Octopus=cephalopod
Pipe=art
Squid=cephalopod
PRINT_TYPE

db_print_type(\%config, 'Squid');
is( $out->read, <<PRINT_TYPE, 'db_print_type one key' );
Squid=cephalopod
PRINT_TYPE

db_print_prop(\%config, 'Squid');
is( $out->read, <<PRINT_PROP, 'db_print_prop all props' );
arms=10
species=Loligo
PRINT_PROP

db_print_prop(\%config, 'Squid', 'arms');
is( $out->read, <<PRINT_PROP, 'db_print_prop one prop' );
arms=10
PRINT_PROP

undef $out;
untie *STDOUT;

db_set(\%config, 'Wibble', 'dribble|hip|hop');
my($type, %props) = db_get(\%config, 'Wibble');
is( $type, 'dribble',   'db_set with raw value' );
is_deeply( \%props, { hip => 'hop' }, '  again' );

db_set(\%config, 'Wibble', 'word', { thingy => 'yep' });
($type, %props) = db_get(\%config, 'Wibble');
is( $type, 'word',      'db_set');
is_deeply( \%props, { thingy => 'yep' } );

db_set_type(\%config, 'Wibble', 'yibble');
is( db_get_type(\%config, 'Wibble'), 'yibble', 'db_set_type' );

db_set_prop(\%config, 'Wibble', har => 'far');
is( db_get_prop(\%config, 'Wibble', 'har'), 'far', 'db_set_prop' );


### Test read-only open()
my $scratch = scratch_copy('10e-smith-lib/configuration.conf');
ok( chmod 0444, $scratch );
my $ro_db = esmith::DB::db->open_ro($scratch);

eval { $ro_db->new_record('wibble', { type => 'something' }) };
like( $@, qr/read-only/ );

my $sshd = $ro_db->get('sshd');
eval { $sshd->set_prop('foo', 'bar') };
like( $@, qr/read-only/ );
is( $sshd->prop('foo'), undef );

eval { $sshd->delete_prop('status') };
like( $@, qr/read-only/ );
isnt( $sshd->prop('status'), undef );

eval { $sshd->merge_props(foo => 'bar') };
like( $@, qr/read-only/ );
is( $sshd->prop('foo'), undef );

eval { $sshd->reset_props(foo => 'bar') };
like( $@, qr/read-only/ );
is( $sshd->prop('foo'), undef );

eval { $sshd->delete };
like( $@, qr/read-only/ );
ok( $ro_db->get('sshd') );
