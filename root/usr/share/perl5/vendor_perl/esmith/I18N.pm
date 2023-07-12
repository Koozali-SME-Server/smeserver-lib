#----------------------------------------------------------------------
# Copyright 1999-2003 Mitel Networks Corporation
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#----------------------------------------------------------------------

package esmith::I18N;

use strict;

use esmith::ConfigDB;
use POSIX qw(setlocale LC_ALL LC_CTYPE);
use Locale::gettext;
use I18N::AcceptLanguage;
use I18N::LangTags qw(is_language_tag locale2language_tag);

=pod

=head1 NAME

esmith::I18N - Internationalization utilities Mitel Network SME Server

=head1 VERSION

This file documents C<esmith::I18N> version B<1.4.0>

=head1 SYNOPSIS

    use esmith::I18N;

    my $i18n = new esmith::I18N;

=head1 DESCRIPTION

This module provides general internationalization and localisation
utilities for developers of the Mitel Networks SME Server.

=begin testing

use I18N::LangTags qw(is_language_tag locale2language_tag language_tag2locale);
use_ok('esmith::I18N');

=end testing

=head1 GENERAL UTILITIES

=cut

sub new
{
    my $self = shift;
    my $class = ref($self) || $self;

    my %args = @_;

    return $self;
}

=head2 availableLocales()

Returns an array containing the available locales supported by the
server.

=begin testing

$ENV{ESMITH_CONFIG_DB}="10e-smith-lib/sysconfig-en_US.conf";
$ENV{ESMITH_I18N_USRSHARELOCALE}="10e-smith-lib/usr/share/locale";

my $i18n = new esmith::I18N;
my @locales = grep !/CVS/, sort $i18n->availableLocales;

# NOTE: de is not a valid locale for the test - no server-console file
is_deeply(\@locales, [('en_US', 'fr_CA', 'wx_YZ')], "Locales match" );

=end testing

=cut

sub availableLocales()
{
    my ($self) = shift;

    my $localedir = $ENV{ESMITH_I18N_USRSHARELOCALE} || '/usr/share/locale';

    return () unless opendir LOCALE, $localedir;

    my @locales;

    foreach my $locale ( grep(!/\./, readdir LOCALE) )
    {
        push @locales, $locale if 
		(-f "$localedir/$locale/LC_MESSAGES/server-console.mo" or
		 -f "$localedir/$locale/LC_MESSAGES/server-console.po");
    }

    closedir LOCALE;
    return @locales;
}

=head2 fallbackLocale()

Return system fallback locale

=cut

sub fallbackLocale()
{
    return "en_US.utf8";
}

=head2 preferredLocale()

Retrieves the preferred locale for this server.

=begin testing

$ENV{ESMITH_CONFIG_DB}="10e-smith-lib/sysconfig-en_US.conf";

my $i18n = new esmith::I18N;
is($i18n->preferredLocale, 'en_US', "en_US.conf: Preferred locale is en_US");

$ENV{ESMITH_CONFIG_DB}="10e-smith-lib/sysconfig-fr_CA.conf";

$i18n = new esmith::I18N;
is($i18n->preferredLocale, 'fr_CA', "fr_CA.conf: Preferred locale is fr_CA");

=end testing

=cut

sub preferredLocale()
{
    my ($self) = shift;

    my $db = esmith::ConfigDB->open_ro || return $self->fallbackLocale;

    my ($locale, @rest) = $db->getLocale();

    return $locale || $self->fallbackLocale;
}

=head2 setLocale()

Configure the locale for gettext() for the supplied text domain.

The method takes two arguments, the text domain, and an optional argument
which can be either a language tag or a locale.

=cut

sub setLocale()
{
    my ($self, $text_domain, $opt) = @_;
    my $locale;

    $locale = $self->langtag2locale($opt) if ($opt);
    $locale ||= $self->preferredLocale;
    $locale =~ s{(?:\..*)?$}{.utf8};

    $ENV{'LANGUAGE'} = $locale;
    $ENV{'LANG'}     = $ENV{'LANGUAGE'};

    setlocale(LC_MESSAGES, $locale);
    setlocale(LC_MESSAGES, $locale);
    setlocale(LC_ALL, $locale);
    setlocale(LC_ALL, $locale);

    bindtextdomain ($text_domain, "/usr/share/locale");
    textdomain ($text_domain);
}


=head2 langtag2locale

Even though the directories appear in /usr/share/locale, they also need
to appear in /usr/lib/locale to actually be treated as locales. Read the
Perl locale docs for details of how horrid this is. For now, we're just
going to force things for supported languages.

=begin testing
my $i18n = new esmith::I18N;

is($i18n->langtag2locale("en"), "en_US", "en langtag is en_US locale");
is($i18n->langtag2locale("en-us"), "en_US", "en-us langtag is en_US locale");
is($i18n->langtag2locale("en-au"), "en_AU", "en-au langtag is en_AU locale");

is($i18n->langtag2locale("es"), "es_ES", "es langtag is es_ES locale");
is($i18n->langtag2locale("es-es"), "es_ES", "es-es langtag is es_ES locale");
is($i18n->langtag2locale("es-ar"), "es_AR", "es-ar langtag is es_AR locale");

is($i18n->langtag2locale("fr"), "fr_CA", "fr langtag is fr_CA locale");
is($i18n->langtag2locale("fr-ca"), "fr_CA", "fr-ca langtag is fr_CA locale");
is($i18n->langtag2locale("fr-fr"), "fr_FR", "fr-fr langtag is fr_FR locale");
=end testing

=cut

sub langtag2locale
{
    my ($self, $opt) = @_;

    my $locale;

    if (is_language_tag($opt))
    {
	$locale = _language_tag2locale($opt) || $self->fallbackLocale;

	unless (-d "/usr/lib/locale/$locale")
	{
	    $locale = "da_DK" if ($opt =~ /^da(-.*)?/);
	    $locale = "de_DE" if ($opt =~ /^de(-.*)?/);
	    $locale = "el_GR" if ($opt =~ /^el(-.*)?/);
	    $locale = "en_US" if ($opt =~ /^en(-.*)?/);
	    $locale = "es_ES" if ($opt =~ /^es(-.*)?/);
	    $locale = "fr_CA" if ($opt =~ /^fr(-.*)?/);
	    $locale = "hu_HU" if ($opt =~ /^hu(-.*)?/);
	    $locale = "id_ID" if ($opt =~ /^id(-.*)?/);
	    $locale = "it_IT" if ($opt =~ /^it(-.*)?/);
	    $locale = "nl_NL" if ($opt =~ /^nl(-.*)?/);
	    $locale = "pt_BR" if ($opt =~ /^pt(-.*)?/);
	    $locale = "sl_SL" if ($opt =~ /^sl(-.*)?/);
	    $locale = "sv_SE" if ($opt =~ /^sv(-.*)?/);
	}
    }
    else 
    {
	$locale = $opt;
    }

    return $locale;
}

sub _language_tag2locale
{
    my $langtags = $_[0];
    my @locales;
    foreach my $maybe (split /[\n\r\t ,]+/, $langtags) 
    {
        push @locales,
        lc($1) . ( $2 ? ('_' . uc($2)) : '' )
            if $maybe =~ m/^([a-zA-Z]{2})(?:-([a-zA-Z]{2}))?$/s;
    }
    return $locales[0] unless wantarray; # might be undef!
        return @locales;  # might be empty!
}

=head2 availableLanguages()

Returns an array containing the available languages supported by the
server.

=begin testing

$ENV{ESMITH_CONFIG_DB}="10e-smith-lib/sysconfig-en_US.conf";
$ENV{ESMITH_I18N_ESMITHLOCALEDIR}="10e-smith-lib/etc/e-smith/locale";

my $i18n = new esmith::I18N;
my @locales =  grep !/CVS/, sort $i18n->availableLanguages;

is_deeply(\@locales, [('en-us', 'es', 'fr-ca', 'jk', 'wx-yz')], "Locales match" );

=end testing

=cut

sub availableLanguages
{
    my ($self) = shift;

    my $localedir = $ENV{ESMITH_I18N_ESMITHLOCALEDIR} || '/etc/e-smith/locale';

    return () unless opendir LOCALE, $localedir;

    my @locales = grep(!/\./, readdir LOCALE);
    closedir LOCALE;
    return @locales;
}

=head2 fallbackLanguage()

Return system fallback language

=cut

sub fallbackLanguage()
{
    return "en-us";
}

=head2 preferredLanguage()

Returns the preferred language, determined by the HTTP_ACCEPT_LANGUAGE
setting from the browser and the available languages on the server.

=begin testing

my $i18n = new esmith::I18N;
delete $ENV{HTTP_ACCEPT_LANGUAGE};

is( $i18n->preferredLanguage(), "en-us", "Preferred language is en-us");
is( $i18n->preferredLanguage("en-us"), "en-us", "Preferred language is en-us");
is( $i18n->preferredLanguage("en-us, fr-ca"), "en-us", "Preferred language is en-us");
is( $i18n->preferredLanguage("fr-ca, en-us"), "fr-ca", "Preferred language is fr-ca");

$ENV{HTTP_ACCEPT_LANGUAGE} = "de, es";
is( $i18n->preferredLanguage(), "es", "Preferred language is es");

$ENV{HTTP_ACCEPT_LANGUAGE} = "de, fr-ca, es, en-us";
is( $i18n->preferredLanguage(), "fr-ca", "Preferred language is fr-ca");

$ENV{HTTP_ACCEPT_LANGUAGE} = "de, es, fr-ca, en-us";
is( $i18n->preferredLanguage(), "es", "Preferred language is es");
=end testing

=cut

sub preferredLanguage
{
    my ($self, $browser_languages) = @_;

    $browser_languages ||= $ENV{HTTP_ACCEPT_LANGUAGE}
    		       ||= $self->fallbackLanguage;

    my @availableLanguages = $self->availableLanguages;

    my $acceptor = I18N::AcceptLanguage->new();
    my $language = $acceptor->accepts($browser_languages, \@availableLanguages)
		   || $self->fallbackLanguage;
}

1;
