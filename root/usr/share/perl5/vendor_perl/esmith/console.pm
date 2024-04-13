#----------------------------------------------------------------------
# Copyright 1999-2006 Mitel Corporation
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#----------------------------------------------------------------------

=head1 NAME

esmith::console - A class to provide a backend library to the server console.

=head1 SYNOPSIS

    use esmith::console;

    my $console = esmith::console->new();

    ($rc, $choice) = $console->message_page
        (
         title   => gettext("Administrator password not set"),
         text    => gettext("Sorry, you must set the administrator password."),
        );

=head1 DESCRIPTION

This class provides a backend library of methods for the frontend console on
the server. The intent is that all of the dialog code is hidden in this
library, and the frontend can just concern itself with the logical progression
through any and all applicable screens.

=head1 Methods

=cut

package esmith::console;

use strict;
use vars qw($VERSION @ISA @EXPORT_OK);
use esmith::util;
use Locale::gettext;
use esmith::ConfigDB;
use esmith::I18N;

@ISA = qw(Exporter);

use constant SCREEN_ROWS => 22;
use constant SCREEN_COLUMNS => 76;
use constant CONSOLE_SCREENS => "/sbin/e-smith/console-screens";

BEGIN
{
    # disable CTRL-C
    $SIG{INT} = 'IGNORE';

    # Set PATH explicitly and clear related environment variables so that calls
    # to external programs do not cause results to be tainted. See
    # "perlsec" manual page for details.

    $ENV {'PATH'} = '/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin';
    $ENV {'SHELL'} = '/bin/bash';
    delete $ENV {'ENV'};
    delete $ENV {'BASH_ENV'};
}

=head2 new

This is the class constructor.

=cut

sub new
{
    my $class = ref($_[0]) || $_[0];
    my $self = {};
    esmith::util::setRealToEffective ();

    my $i18n = new esmith::I18N;
    $i18n->setLocale("server-console");

    #------------------------------------------------------------
    # Set stdin, stdout and stderr to console
    #------------------------------------------------------------

    if (defined $ARGV [0])
    {
	$ARGV[0] =~ /(console|tty\d*)/ && -c "/dev/$1"
	    or die gettext("Bad ttyname:"), " ", $ARGV[0], "\n";
	my $tty = $1;

	open (STDIN,  "</dev/$tty") or die gettext("Can't redirect stdin"),  ": $!\n";
	open (STDOUT, ">/dev/$tty") or die gettext("Can't redirect stdout"), ": $!\n";

	my $pid = open(STDERR, "|-");
	die gettext("Can't fork"), ": $!\n" unless defined $pid;

	unless ($pid)
	{
	    exec qw(/usr/bin/logger -p local1.info -t console);
	}
    }

    $self = bless $self, $class;
    return $self;
}

=head2 screen and dialog

These method are wrappers around dialog, and permit the creation
of custom screens depending on the arguments passed. They are typically not
called directly, but are used by all of the other page methods that
follow. You should only call these method directly if none of the other
methods apply.

=cut

sub screen
{
    _screen(shift, "/usr/bin/dialog", @_);
}

sub dialog
{
    _screen(shift, "/usr/bin/dialog", @_);
}

sub _screen
{
    my $self = shift;
    my $whiptail = shift;
    my @whiptailArgs = @_;

    # now would be a good time to flush output buffers, so the partial
    # buffers don't get copied:

    $| = 1;
    print "";

    pipe (READER, WRITER)
        or die gettext("Couldn't create pipe") . ": $!\n";

    my $pid = fork;

    if (! defined $pid)
    {
        die gettext("Couldn't fork") . ": $!\n";
    }

    elsif ($pid == 0)
    {
        #----------------------------------------
        # Child
        #----------------------------------------

        # Attach child's STDIN to the reading end of the pipe
        close READER
            or die gettext("Couldn't close reading end of pipe") , ": $!\n";

        use Fcntl qw/F_SETFD/;

        # Clear close-on-exec on WRITER so that it stays open for dialog to use
        fcntl(WRITER, F_SETFD, 0);

        unshift @whiptailArgs, $whiptail,
                '--backtitle', $self->backtitle, "--output-fd", fileno(WRITER);
        exec @whiptailArgs;
        die gettext("Couldn't exec:"), ": $!\n";
    }

    #----------------------------------------
    # Parent
    #----------------------------------------

    close WRITER;

    my $choice = <READER>;
    close READER;

    waitpid ($pid, 0);
    my $rc = $?;

    return ($rc, $choice);
}

=head2 backtitle

Console header line for each page

=cut

sub backtitle
{
    my $self = shift;

    my $db = esmith::ConfigDB->open_ro or die "Couldn't open ConfigDB\n";

    sprintf("%-33s%45s",
    ($db->get_prop('sysconfig', 'ProductName') || "SME Server") . " " .
    ($db->get_prop('sysconfig', 'ReleaseVersion') || "UNKNOWN"),
    "Copyright (C) 1999-2006 Mitel Corporation, Copyright (C) ____COPYYEARS____ Koozali Foundation, Inc."
    );
}

=head2 message_page

This method should be used whenever a screen that displays a simple message
is required.

=cut

sub message_page
{
    my $self = shift;
    my %params = @_;

    my $title       = $params{title};
    my $message_box = $params{text};

    my $left  = defined $params{left} ? $params{left} : gettext("Back");
    my $right = defined $params{right} ? $params{right} : gettext("Next");

    $self->screen ("--title",  $title,
                   "--cancel-label",   $left,
                   "--ok-label",  $right,
                   "--clear",
                   "--msgbox", $message_box,
                   SCREEN_ROWS,
                   SCREEN_COLUMNS,
                  );
}

=head2 tryagain_page

This method displays a simple "try again" screen.

=cut

sub tryagain_page
{
    my $self = shift;
    my %params = @_;

    my $title  = $params{title};
    my $choice = $params{choice};

    my $try_again = "; " . gettext("please try again");

    my $message_box = $title . ":'${choice}'" . $try_again;

    $self->screen ("--title",  $title,
                   "--cancel-label",  gettext("Back"),
                   "--ok-label", gettext("Next"),
                   "--clear",
                   "--msgbox", $message_box,
                   SCREEN_ROWS,
                   SCREEN_COLUMNS,
                  );
}

=head2 password_page

This method displays a screen suitable for entering a password.

=cut

sub password_page
{
    my $self = shift;
    my %params = @_;

    my $title       = $params{title};
    my $message_box = $params{text};

    my $left  = defined $params{left} ? $params{left} : gettext("Back");
    my $right = defined $params{right} ? $params{right} : gettext("Next");

    $self->dialog ("--title",  $title,
                   "--insecure",
                   "--cancel-label",  $left,
                   "--ok-label", $right,
                   "--clear",
                   "--passwordbox", "\n" . $message_box,
                   SCREEN_ROWS,
                   SCREEN_COLUMNS,
                  );
}

=head2 yesno_page

This method displays a simple yes/no screen, so the user can make a
simple binary selection.

=cut

sub yesno_page
{
    my $self = shift;
    my %params = @_;

    my $title = $params{title};
    my $text  = $params{text};

    my $left  = defined $params{left} ? $params{left} : gettext("Yes");
    my $right = defined $params{right} ? $params{right} : gettext("No");
    my @args = (
	    "--title" =>  $title,
	    "--yes-label" =>   $left,
	    "--no-label" =>  $right,
	);
    push @args, "--defaultno" if defined $params{defaultno};
    push @args, "--clear";

    $self->screen (@args,
                   "--yesno",  $text,
                   SCREEN_ROWS,
                   SCREEN_COLUMNS,
                  );
}

=head2 input_page

This method displays a simple input screen with an input box.

=cut

sub input_page
{
    my $self = shift;
    my %params = @_;

    my $title  = $params{title};
    my $text   = $params{text};
    my $value  = $params{value};

    my $left  = defined $params{left} ? $params{left} : gettext("Back");
    my $right = defined $params{right} ? $params{right} : gettext("Next");

    $self->screen("--title", $title,
                  "--cancel-label",  $left,
                  "--ok-label", $right,
                  "--clear",
                  "--inputbox", $text,
                  SCREEN_ROWS,
                  SCREEN_COLUMNS,
                  $value
                 );
}

=head2 infobox

This method is similar to a messagebox, but exits immediately, without clearing the screen.

=cut

sub infobox
{
    my $self = shift;
    my %params = @_;
    my $title  = $params{title};
    my $text   = $params{text};
    my $height = $params{height} || "8";
    my $width  = $params{width} || SCREEN_COLUMNS;
    $self->screen("--title", $title,
                  "--infobox", $text,
                  $height,
                  $width,
                 );
}


=head2 textbox

A text box lets you display the contents of a text file in a dialog box.
It is like a simple text file viewer.

=cut

sub textbox
{
    my $self = shift;
    my %params = @_;
    my $title  = $params{title};
    my $file   = $params{file};
    my $height = $params{height} || '20';
    my $width  = $params{width} || SCREEN_COLUMNS;
    $self->screen("--title", $title,
                  "--textbox", $file,
                  $height,
                  $width,
                 );
}

=head2 menu_page

This method displays a screen with a menu.

=cut

sub menu_page
{
    my $self = shift;
    my %params = @_;

    my $title = $params{title};
    my $text  = $params{text};
    my @args = ("--clear", "--title", $title);
    if ($params{default})
    {
        push @args, "--default-item", $params{default};
    }

    my $value     = $params{value};
    my $argsref   = $params{argsref};

    my $menu_rows = scalar @$argsref / 2;

    $menu_rows = 10 if ($menu_rows > 10);

    my $left  = defined $params{left} ? $params{left} : gettext("Back");
    my $right = defined $params{right} ? $params{right} : gettext("Next");

    $self->dialog(@args,
                  "--cancel-label",  $left,
                  "--ok-label", $right,
                  "--menu", $text,
                  SCREEN_ROWS,
                  SCREEN_COLUMNS,
                  $menu_rows,
                  @$argsref,
                 );
}

=head2 keep_option

??

=cut

sub keep_option
{
    my $self = shift;
    my ($value) = @_;

    my $keep_phrase = gettext("Keep the current setting");

    return ( gettext("keep"), "${keep_phrase}: $value" );
}

=head2 gauge

This method displays a progress bar. It takes a coderef as parameter, and uses
the coderef to drive the --gauge widget of the dialog program, as well as to
perform whatever actions are being reported by the progress bar. The coderef
should take one parameter, which is the file handle to write the controlling
text to. If the return value of the coderef is defined, it is displayed by a
message_page after the progress bar terminates.

All text used to update the progress bar should either be numbers between 0
and 100, or arbitrary text sandwiched between leading and training lines
of 'XXX' followed by newline. The numbers will update the percentage complete
of the display, and the text will update the displayed text. Updating the
displayed text will reset the precentage complete to 0, so text should always
be followed by number.

=cut

sub gauge
{
    my $self = shift;
    my $sub = shift;
    my %params = @_;
    my $title              = $params{title} || 'Progress';
    my $feedback_title     = $params{feedback_title} || 'Status';
    my $init_text          = $params{text} || 'Progress';
    my @args = (
		'--backtitle', $self->backtitle,
		'--title', gettext($title),
	);
    push @args, "--clear" if $params{clear};
    push @args, "--colors" if $params{colors};
    push @args, "--no-collapse" if $params{no_collapse};

    use FileHandle;

    unless (open(WR, '|-'))
    {
	exec('/usr/bin/dialog',
		@args,
		'--gauge',
		gettext($init_text),
                SCREEN_ROWS,
                SCREEN_COLUMNS,
		);
    }
    WR->autoflush(1);
    my $text = &$sub(*WR);
    close(WR);
    $self->message_page('title' => $feedback_title, 'text' => $text)
	if defined $text;
}

=head2 run_screens

This method takes a directory of screens to run, and runs them in order.
To support navigation between screens, this method respects an integer
return value from the screens.

    0 = all is well, continue to the next screen
    1 = all is not well, go back to the previous screen
    2 = catastrophic failure - return from run_screen

=cut

sub run_screens
{
    my $self = shift;
    my ($subdir) = @_;

    my $dir = CONSOLE_SCREENS . "/$subdir";

    # This is fine. Noop if the directory isn't there.
    unless (-d $dir)
    {
	return 1;
    }

    # This is not fine. If it's there, we should be able to open it.
    unless ( opendir(SCREENS, $dir) )
    {
	warn "Failed to open directory $dir: $!\n";
        return 0;
    }

    my @screens = sort grep (!/^(\.\.?)$/, readdir (SCREENS));

    my @previous_screens = ();
    while (@screens)
    {
        my $screen = shift @screens;
        unless ( $screen =~ /(S\d\d[\d\w]+)/ )
        {
            warn "Unknown screen type $dir/$screen\n";
            next;
        }

        $screen = $1;
        my $rv = system( "$dir/$screen" );
        $rv >>= 8;
        if ($rv == 0)
        {
            # Success, move to next screen.
            push @previous_screens, $screen;
        }
        elsif ($rv == 1)
        {
            # Failure, go back one screen.
            unshift @screens, $screen;
            if (@previous_screens)
            {
                unshift @screens, pop @previous_screens;
            }
            else
            {
                # We're at the beginning of the stack. Just return.
                return 0;
            }
        }
        else
        {
            # Catastrophic failure, return. While 2 is the agreed-upon
            # return code for this, consider it a catastrophic failure
            # if we don't get a valid return code.
            return 0;
        }
    }
    return 1;
}

=head1 AUTHOR

SME Server Developers <smebugs@mitel.com>

=cut

1;
