#----------------------------------------------------------------------
# Copyright (C) 2024 Koozali Foundation inc.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#----------------------------------------------------------------------

package esmith::util::ldap;

use strict;
use Errno;
use esmith::ConfigDB;
use esmith::AccountsDB;
use esmith::util;
use utf8;
use Encode;
use Unicode::Normalize;
use Text::Unidecode;
use Net::LDAP;
use List::MoreUtils qw(uniq);

require Exporter;
our @ISA = qw(Exporter Net::LDAP);

# Exporting as default.
our @EXPORT = qw(stringToASCII ldapgroup ldapdelgroup ldapsetgroupmembers ldapaddgroupmembers ldapuser ldapdeluser ldaplockuser ldapaddmachine ldapdelmachine);
# Exporting on demand basis.
our @EXPORT_OK = qw(ldapaddgroup ldapmodgroup ldapadduser ldapmoduser ldapexistsgroup ldapexistsuser ldapread);

#TODO:
#=for testing
#use_ok('esmith::util::system', 'killall', 'rsync', 'rsync_ssh');

my $c = esmith::ConfigDB->open_ro || die "Couldn't open config db\n";
our $domain = $c->get('DomainName')
    || die("Couldn't determine domain name");
$domain = $domain->value;


=pod

=head1 NAME

esmith::util::ldap - wrappers for ldap commands

=head1 SYNOPSIS

  use esmith::util::ldap;


=head1 DESCRIPTION

This is for common functions that would normally require a complete setting 
to bind and acces localhost LDAP server in order to read, add or modify entries

It is mostly a set of wrappers based on Net::LDAP.
If you find yourself writing a ldap related function, consider putting it
in here.


=head2 Functions

These may be pure Perl functions or they may well just be wrappers
around Net::LDAP.

Each can be imported on request.

=over 4

=begin testing
#TODO
=end testing

=head2 new()
Initiate the perl object and binds to SME Server localhost ldap

=cut

sub new {
  my $self = shift;
  my $obj  = bless {}, $self;
  my $c = esmith::ConfigDB->open_ro || die "Couldn't open config db\n";
  my $a = esmith::AccountsDB->open_ro || die "Couldn't open accounts db\n";

  # prepare LDAP bind ; Fail safe : if not root can not read password file !
  my $pw = esmith::util::LdapPassword();
  my $base = $self->base; 

  $obj = Net::LDAP->new('localhost')
      or die "$@";

  $obj->bind(
      dn => "cn=root,$base",
      password => $pw
  );
  return bless $obj, $self;
};

=pod

=head2 base()

Display base for ldap search or other usage
 e.g. ou=domain,ou=org

=cut

sub base {
  my $self = shift;
  my $c = esmith::ConfigDB->open_ro || die "Couldn't open config db\n";
  return esmith::util::ldapBase ($domain); 
}

=head2 ldapgroup($group{})
Check if group is in ldap:
- if not it calls addgroup
- if yes it calls modgroup
It expects as argument output of e-smith account db $account->get($key).
It returns whatever addgroup or modgroup will.

=cut
sub ldapgroup {
  my $self = shift ;
  my $group = shift;
  # get $key, this tests if not an account hash  and returns 255
  my $key = $group->key or return 255;
  # get $type, if not returns 254, could also filter for user,group,system.ibay,machine...
  my $type = $group->prop('type') or return 254;
  # check if exists
  # yes : modgroup
  # no : addgroup
  return ($self->ldapexistsgroup($key))? $self->ldapmodgroup($group) : $self->ldapaddgroup($group);
}

=pod

=head2 ldapaddgroup($group{})

Insert new group in ldap and return ldap err code if any.
It expects as argument output of e-smith account db $account->get($key).
From the type, it will extrapolate if we add a real group, an user main group 
or an ibay group and chose the content to add.

=cut

sub ldapaddgroup {
  my $self = shift ;
  my $acct = shift;
  my $base = $self->base;
  # get $key, this tests if not an account hash  and returns 255
  my $acctName = $acct->key or return 255;
  # get $type, if not what we want returns 254
  my $type = $acct->prop('type') or return 254;
  my $uid = $acct->prop('Uid') ;
  my $gid = $acct->prop('Gid') || $uid; # this is a user group
  # create the hash to submit with values common to all
  my %attrs = (
    "cn"=> $acctName,
    "gidNumber"=> $gid,
    "objectClass" => [ 'posixGroup', 'mailboxRelatedObject'],
   );
  if ($type eq "group") {
    $attrs{'description'} = $self->stringToASCII($acct->prop('Description') || $acctName );
    $attrs{'mail'} = "$acctName\@$domain";
  } 
  if ($type eq "ibay") {
    $attrs{'description'} = $self->stringToASCII($acct->prop('Name') || $acctName );
    #$attrs{'mail'} = "$acctName\@$domain";# we might want to set email for ibay there?
    $attrs{'objectClass'} = ['posixGroup'];
  }
  if ($type eq "machine") {
    $attrs{'objectClass'} = ['posixGroup'];
  }
  # Create the group in ldap
	my $result = $self->add("cn=$acctName,ou=Groups,$base",
		attrs => [ %attrs ]);
	return $result->code 
}

=pod

=head2 ldapmodgroup($group{})

It modifies the group in ldap and return ldap err code if any.
It expects as argument output of e-smith account db $account->get($key).
It is assumed the group exists, please use ldapgroup() as failsafe. Before altering, 
ldap content, it will first check that the content has change to avoid unnecessary 
ldap write access.

=cut

sub ldapmodgroup {
  my $self = shift ;
  #get variables an sanitize
  my $acct = shift;
  my $base = $self->base;
  # get $key, this tests if not an account hash  and returns 255
  my $acctName = $acct->key or return 255;
  # get $type, if not what we want returns 254
  my $type = $acct->prop('type') or return 254;
  my $gid = $acct->prop('Gid') or return 253;
  # create the hash to submit with values common to all
  my %attrs = (
    "cn"=> [$acctName],
    "gidNumber"=> [$gid],
   );
  if ($type eq "group") {
    $attrs{'description'} = [ $self->stringToASCII($acct->prop('Description') || $acctName )  ];
    $attrs{'mail'} = [ "$acctName\@$domain" ];
  }
  if ($type eq "ibay") {
    $attrs{'description'} = [ $self->stringToASCII($acct->prop('Name') || $acctName ) ] ;
    #$attrs{'mail'} = [ "$acctName\@$domain" ];
  }
  # if type user we add nothing
  #get current content
  #list attributes
  my $result;
  my @list = keys %attrs;
  $result = $self->search ( base    => "cn=$acctName,ou=Groups,$base",
                               filter => "(objectClass=*)",
                               attrs   =>  [ @list ]
                             );
  my $href = $result->as_struct;
  my @arrayOfDNs  = keys %$href;
  $href = $$href{$arrayOfDNs[0]};
  # filter out fields without changes
  for my $field (@list){
     delete($attrs{$field}) if ( defined($href->{lc($field)})  and $href->{lc($field)}[0] eq $attrs{$field}[0]);
  }
  # return if nothing to change
  return 0 unless  ( %attrs);
  #use replace for any change  
  $result = $self->modify("cn=$acctName,ou=Groups,$base",
                      replace =>  %attrs
    );
  return $result->code;
}

=pod

=head2 ldapsetgroupmembers($groupName,\@groupMembers)

will set all members in array to this group.
=cut

sub ldapsetgroupmembers {
  my $self = shift ;
  my $groupName = shift;
  my $base = $self->base;
  my $groupMembers_ref = shift;
  my @groupMembers =  @{ $groupMembers_ref };
  my $arrSize =  scalar @groupMembers;
  # add admin, www to group if SME group group, not for ibays,user,computers dedicated group
  my $a = esmith::AccountsDB->open_ro || die "Couldn't open accounts db\n";
  push @groupMembers, 'admin', 'www' if ( $a->get($groupName) and $a->get($groupName)->prop("type") eq "group");
  #remove duplicates 
  @groupMembers = uniq @groupMembers; 
  #TODO check that we are not sending empty array 
  #TODO check that it actually needs updating to avoid write access
  my $result = $self->modify("cn=$groupName,ou=Groups,$base",
    replace => {
         "memberUid"=> \@groupMembers
  });
  return  $result->code;
}

=pod

=head2 ldapaddgroupmembers($groupName,\@groupMembers)

will add members in array to this group. not removing existing
members. will return code 20 if one exist.
=cut

sub ldapaddgroupmembers{
  my $self = shift ;
  my $groupName = shift;
  my $base = $self->base;
  my $groupMembers_ref = shift;
  my @groupMembers =  @{ $groupMembers_ref };
  my $arrSize =  scalar @groupMembers;
  #TODO check that we are not sending empty array 
  #TODO check that it actually needs updating to avoid write access
  my $result = $self->modify("cn=$groupName,ou=Groups,$base",
    add => {
         "memberUid"=> \@groupMembers
  });
  return  $result->code;
}

=pod

=head2 ldapdelgroup($groupName)

Will delete the group which groupname is provided.
Returns ldap error code if any.

=cut

sub ldapdelgroup {
  my $self = shift ;
  my $groupName = shift;
  my $base = $self->base;
  my $result = $self->delete("cn=$groupName,ou=Groups,$base");
  return  $result->code;
}

=pod

=head2 ldapexistsgroup($groupName)

Will check if group exists in ldap.
Returns 0 if not, and 1 if it does.

=cut

sub ldapexistsgroup {
  my $self = shift ;
  my $groupName = shift;
  my $base = $self->base;
  my $result = $self->search ( base    => "cn=$groupName,ou=Groups,$base",
                               filter => "(objectClass=*)",
                               attrs   =>  ["uid"]
                             );
  return ($result->code)? 0:1;
}

=head2 ldapuser($user{})
Check if user is in ldap:
- if not it calls ldapadduser
- if yes it calls ldapmoduser
It expects as argument output of e-smith account db $account->get($key).
It returns whatever ldapadduser or ldapmoduser will.

=cut

sub ldapuser {
  my $self = shift ;
  my $user = shift;
  # get $key, this tests if not an account hash  and returns 255
  my $key = $user->key or return 255;
  # get $type, if not what we want returns 254, we could also filter forallowed type
  my $type = $user->prop('type') or return 254;
  # check if exists
  # yes : ldapmodgroup
  # no : ldapaddgroup
  return ($self->ldapexistsuser($key))? $self->ldapmoduser($user) : $self->ldapadduser($user);
}

=pod

=head2 ldapadduser($user{})

Insert new user in ldap and return ldap err code if any.
It expects as argument output of e-smith account db $account->get($key).
From the type, it will extrapolate if we add a real user, a dummy group user  
or a dummy ibay group and chose the content to add.

=cut

sub ldapadduser {
  my $self = shift; 
  #check if posixAccount or dummy for group/Machine/ibay
  my $acct = shift;
  my $base = $self->base;
  # get $key, this tests if not an account hash  and returns 255
  my $acctName = $acct->key or return 255;
  # get $type, if not what we want returns 254
  my $type = $acct->prop('type') or return 254;
  my $uid =  $acct->prop('Uid') or return 253;
  my $gid = $acct->prop('Gid') || $uid ;
  my $first = $self->stringToASCII($acct->prop('FirstName')) || '';
  my $last = $self->stringToASCII($acct->prop('LastName')) || '';
  my $phone = $self->stringToASCII($acct->prop('Phone')) || '';
  my $company = $self->stringToASCII($acct->prop('Company')) || '';
  my $dept = $self->stringToASCII($acct->prop('Dept')) || '';
  my $city = $self->stringToASCII($acct->prop('City')) || '';
  my $street = $acct->prop('Street') || '';
  my $shell =  $acct->prop('Shell') || '/usr/bin/false';

  # create the hash to submit with values common to all
  my %attrs = (
    "uidNumber" => $uid,
    "gidNumber"=> $gid,
    "objectClass" => [ 'inetOrgPerson', 'posixAccount', 'shadowAccount' ],
    "homeDirectory" => "/home/e-smith/files/users/$acctName",
    "loginShell" => "$shell",
    "shadowExpire" => -1,
    "shadowFlag" => 134538308,
    "shadowInactive" => -1,
    "shadowLastChange" => 15997,
    "shadowMax" => 99999,
    "shadowMin" => -1,
    "shadowWarning"=> 7,
    'userPassword' => "{crypt}!*"
   );
  if ($type eq "user") {
     $attrs{"cn"}= "$first $last";
     $attrs{"givenName"}= "$first";
     $attrs{"sn"}= "$last";
     $attrs{"displayName"}= "$first $last";
     $attrs{"mail"}= "$acctName\@$domain";
     $attrs{"telephoneNumber"}= $phone;
     $attrs{"o"}= $company;
     $attrs{"ou"}= $dept;
     $attrs{"l"}=  $city;
     $attrs{"street"}= $street;
  } elsif ($type eq "group")  {
     $attrs{"objectClass"}=['account', 'posixAccount', 'shadowAccount'];
     $attrs{"cn"}=$acctName;
     $attrs{"homeDirectory"} = "/home/e-smith";
     $attrs{"loginShell"} = "/bin/false";
  } elsif ($type eq "ibay")  {
     my $Name = $self->stringToASCII($acct->prop('Name')) || $acctName;
     $attrs{"objectClass"}=['account', 'posixAccount', 'shadowAccount'];
     $attrs{"cn"}=$Name;
     $attrs{"homeDirectory"} = "/home/e-smith/files/ibays/$acctName";
     $attrs{"loginShell"} = "/bin/false";
  }
  # Create the group in ldap
  my $result = $self->add("uid=$acctName,ou=Users,$base",
    attrs => [ %attrs ]);
  return $result->code
}

=pod

=head2 ldapmoduser($user{})

Updates user.
It modifies the user in ldap and return ldap err code if any.
It expects as argument output of e-smith account db $account->get($key).
It is assumed the user exists, please use ldapuser() as failsafe. Before altering,
ldap content, it will first check that the content has change to avoid unnecessary
ldap write access.

=cut 

sub ldapmoduser {
  my $self = shift ;
  my $acct = shift;
  my $base = $self->base;
  # get $key, this tests if not an account hash  and returns 255
  my $acctName = $acct->key or return 255;
  # get $type, if not what we want returns 254
  my $type = $acct->prop('type') or return 254;
  my $uid =  $acct->prop('Uid') or return 253;
  my $gid = $acct->prop('Gid') || $uid;
  my $first = $self->stringToASCII($acct->prop('FirstName')) || '';
  my $last = $self->stringToASCII($acct->prop('LastName')) || '';
  my $phone = $self->stringToASCII($acct->prop('Phone')) || '';
  my $company = $self->stringToASCII($acct->prop('Company')) || '';
  my $dept = $self->stringToASCII($acct->prop('Dept')) || '';
  my $city = $self->stringToASCII($acct->prop('City')) || '';
  my $street = $self->stringToASCII($acct->prop('Street')) || '';
  my $shell =  $acct->prop('Shell') || '/usr/bin/false';
  # create the hash to submit with values common to all
  my %attrs = (
    "uidNumber" => $uid,
    "gidNumber"=>  $gid ,
    "homeDirectory" => "/home/e-smith/files/users/$acctName",
    "loginShell" => "$shell",
   );
  if ( $type eq "user") {
    $attrs{"cn"}= "$first $last";
    $attrs{"givenName"}=$first;
    $attrs{"mail"}="$acctName\@$domain";
    $attrs{"sn"}=$last;
    $attrs{"telephoneNumber"}=$phone;
    $attrs{"o"}= $company;
    $attrs{"ou"}=$dept;
    $attrs{"l"}=$city;
    $attrs{"street"}=$street;
    $attrs{"displayName"}= "$first $last";
  } elsif ($type eq "group")  {
    $attrs{"homeDirectory"}="/home/e-smith/";
    $attrs{"loginShell"} = "/bin/false";
    $attrs{"cn"}=$acctName;
  } elsif ($type eq "ibay")  {
    my $Name = $self->stringToASCII($acct->prop('Name')) || $acctName; 
    $attrs{"cn"}=$Name;
    $attrs{"homeDirectory"} = "/home/e-smith/files/ibays/$acctName";
    $attrs{"loginShell"} = "/bin/false";
  }
  #get current content
  #list attributes
  my $result;
  my @list = keys %attrs;
  $result = $self->search ( base    => "uid=$acctName,ou=Users,$base",
                               filter => "(objectClass=*)",
                               attrs   =>  [ @list ]
                             );
  my $href = $result->as_struct;
  my @arrayOfDNs  = keys %$href;
  $href = $$href{$arrayOfDNs[0]};
  # filter out fields without any change.
  for my $field (@list){
     delete($attrs{$field}) if ( defined ($href->{lc($field)}) and $href->{lc($field)}[0] eq $attrs{$field});
  }
  # return if nothing changed
  return 0 unless  ( %attrs);
  # update only if changes 
  $result = $self->modify("uid=$acctName,ou=Users,$base",
                      replace => [ %attrs]
        );
  return $result->code;
}


=pod

=head2 ldaplockuser($username)

Lock a user password

=cut

sub ldaplockuser {
  my $self = shift ;
  my $userName = shift;
  my $base = $self->base;
  my $result = $self->modify("uid=$userName,ou=Users,$base",
               replace => { 'userPassword' => "{crypt}!*"});
 return $result->code;
}

=pod

=head2 ldapdeluser($userName)

Will delete the user which username is provided.
Returns ldap error code if any.

=cut

sub ldapdeluser {
  my $self = shift ;
  my $userName = shift;
  my $base = $self->base;
  my $result = $self->delete("uid=$userName,ou=Users,$base");
  return  $result->code;
}

=pod

=head2 ldapexistsuser($userName)

Checks if user does exists in ldap.

=cut

sub ldapexistsuser {
  my $self = shift ;
  my $userName = shift;
  my $base = $self->base;
  my $result = $self->search ( base    => "uid=$userName,ou=Users,$base",
                               filter => "(objectClass=*)",
                               attrs   =>  ["uid"]
                             );
  return ($result->code)? 0:1;
}


# TODO machine account add modify delete

=pod

=head2 ldapaddmachine($m{})

Insert new Machine in ldap and return ldap err code if any.
It expects as argument output of e-smith account db $account->get($key).

=cut

sub ldapaddmachine {
 my $self = shift ;
 my $acct = shift;
 my $machineName = $acct->key or return 253;
 my $uid = $acct->prop('Uid') or return 253;
 return 253 unless ($acct->prop('type') eq "machine");
 my $gid = $acct->prop('Gid') || $uid;
 my $base = $self->base;
 my $result = $self->add("uid=$machineName,ou=Computers,$base",
     attrs => [
        "uidNumber" => $uid,
        "gidNumber" => $gid,
        "cn" => "Hostname account for $machineName",
        "objectClass" => [ 'account','posixAccount', 'shadowAccount'],
        "homeDirectory" => "/noexistingpath",
        "loginShell" => "/bin/false",
        "shadowExpire" => -1,
        "shadowFlag" => 134538308,
        "shadowInactive" => -1,
        "shadowLastChange" => 15997,
        "shadowMax" => 99999,
        "shadowMin" => -1,
        "shadowWarning"=> 7,
        "userPassword" => "{crypt}!*"
        ]
    );
 return $result->code
}

=pod

=head2 ldapdelmachine($machineName)

Will delete the user which machinename is provided.
Returns ldap error code if any.

=cut

sub ldapdelmachine {
  my $self = shift ;
  my $machineName = shift;
  my $base = $self->base;
  my $result = $self->delete("uid=$machineName,ou=Computers,$base");
  return  $result->code;
}



=pod

=head2 ldapread($entry)

Will returns all the field of an existing entry in ldap.
Should provides something like "uid=john,ou=Users" or
"cn=groupname,ou=Groups".
This is an easy way of verifying all is good in db.

=cut

sub ldapread {
 my $self = shift ;
 my $entry = shift ;
 my $base = $self->base;
 
  my $result = $self->search ( base    => "$entry,$base",
                               filter => "(objectClass=*)",
                               attrs   =>  [  ]
                             );
  return $result->code  if $result->error > 0;
  my $href = $result->as_struct;
  # get an array of the DN names
  my @arrayOfDNs  = keys %$href;        # use DN hashes
  # process each DN using it as a key
  foreach ( @arrayOfDNs ) {
    print $_, "\n";
    my $valref = $$href{$_};
    # get an array of the attribute names
    # passed for this one DN.
    my @arrayOfAttrs = sort keys %$valref; #use Attr hashes
    my $attrName;
    foreach $attrName (@arrayOfAttrs) {
      # skip any binary data: yuck!
      next if ( $attrName =~ /;binary$/ );
      # get the attribute value (pointer) using the
      # attribute name as the hash
      my $attrVal =  @$valref{$attrName};
      print "\t $attrName: @$attrVal \n";
    }
    print "#-------------------------------\n";
    # End of that DN
  }
}

=pod

=head2 stringToASCII($string)

Will convert srings from UTF8 to ASCII where it is required to be ASCII.

=cut

sub stringToASCII {
	my $self = shift ; 
  my $string = (ref($self) eq "esmith::util::ldap") ? shift : $self;
  return  unless ($string);
  my $decomposed = NFKD( unidecode($string) );
  $decomposed =~ s/\p{NonspacingMark}//g;
  return $decomposed;
}

