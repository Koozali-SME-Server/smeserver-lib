#----------------------------------------------------------------------
# Copyright 1999-2003 Mitel Networks Corporation
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#----------------------------------------------------------------------

package esmith::cgi;

use strict;
use esmith::config;
use esmith::db;
use esmith::util;

BEGIN
{
}


=pod

=head1 NAME

esmith::cgi - Useful CGI routines for e-smith server and gateway

=head1 VERSION

This file documents C<esmith::cgi> version B<1.4.0>

=head1 SYNOPSIS

    use esmith::cgi;

=head1 DESCRIPTION

This module contains a collection of useful routines for working with
the e-smith manager's CGI interface.
=head1 WEB PAGE HEADER GENERATION ROUTINES

=head2 genHeaderNonCacheable($q, $confref, $title)

=cut

sub genHeaderNonCacheable
{
    my ($q, $confref, $title) = @_;
    genHeader ($q, $confref, $title, '-20y', 1);
}

=pod

=head2 genHeaderCacheableNoPasswordCheck($q, $confref, $title)

=cut

sub genHeaderCacheableNoPasswordCheck
{
    my ($q, $confref, $title) = @_;
    genHeader ($q, $confref, $title, '+1d', 0);
}

=pod

=head2 genHeaderCacheableNoPasswordCheck($q, $confref, $title)

=cut

sub genHeaderNonCacheableNoPasswordCheck
{
    my ($q, $confref, $title) = @_;
    genHeader ($q, $confref, $title, '-20y', 0);
}

=pod

=head2 genHeader($q, $confref, $title, $expiry, $checkpassword)

=cut

sub genHeader
{
    my ($q, $confref, $title, $expiry, $checkpassword) = @_;

    print $q->header (-EXPIRES => $expiry, charset => 'UTF-8');

    genHeaderStartHTML ($q, "panel_main");

    print $q->h1 ($title);
}

=pod

=head2 genNavigationHeader($q)

=cut

sub genNavigationHeader
{
    my ($q, $num) = @_;

    print $q->header (-EXPIRES => '-20y', charset => 'UTF-8');

    genHeaderStartHTML ($q, "panel_nav", $num);
}

=pod

=head2 genNoframesHeader($q)

=cut

sub genNoframesHeader
{
    my ($q) = @_;

    print $q->header (-EXPIRES => '-20y', charset => 'UTF-8');
    genHeaderStartHTML ($q, "panel_main");
}

=pod

=head2 genHeaderStartHTML($q)

=cut

sub genHeaderStartHTML 
{
    my ($q, $page_type, $num) = @_;
    my ($cssFile);
    my ($bodyStyle);
    my ($script) = "//This swaps the class of the selected item.\n"
    ."function swapClass(){\n"
    ."var i,x,tB,j=0,tA=new Array(),arg=swapClass.arguments;\n"
    ."if(document.getElementsByTagName){for(i=4;i<arg.length;i++){tB=document.getElementsByTagName(arg[i]);\n"
    ."for(x=0;x<tB.length;x++){tA[j]=tB[x];j++;}}for(i=0;i<tA.length;i++){\n"
    ."if(tA[i].className){if(tA[i].id==arg[1]){if(arg[0]==1){\n"
    ."tA[i].className=(tA[i].className==arg[3])?arg[2]:arg[3];}else{tA[i].className=arg[2];}\n"
    ."}else if(arg[0]==1 && arg[1]=='none'){if(tA[i].className==arg[2] || tA[i].className==arg[3]){\n"
    ."tA[i].className=(tA[i].className==arg[3])?arg[2]:arg[3];}\n"
    ."}else if(tA[i].className==arg[2]){tA[i].className=arg[3];}}}}}\n";

    if    ($page_type eq "panel_nav")  { 
        $cssFile = "sme_menu.css";
        $bodyStyle = "menu"
    }
    elsif ($page_type eq "panel_main") { 
        $cssFile = "sme_main.css"; 
        $bodyStyle = "main"
    }
    # the -CLASS thing gets sent as a body class, not in the header
    print $q->start_html (-TITLE        => 'SME Server server manager',
              -META         => {'copyright' => 'Copyright 1999-2006 Mitel Networks Corporation, Copyright (C) ____COPYYEARS____ Koozali Foundation, Inc.'},
			  -SCRIPT       => "$script",
                          -CLASS        => "$bodyStyle",
                          -STYLE        => {
				-code => '@import url("/server-common/css/'.$cssFile.'");',
				-src => '/server-common/css/sme_core.css'
				});
}

=pod

=head1 WEB PAGE FOOTER GENERATION ROUTINES

=head2 genFooter($q)

=cut

sub genFooter
{
    my ($q) = @_;

    if ($q->isa('CGI::FormMagick'))
    {
        print $q->parse_template("/etc/e-smith/web/common/foot.tmpl");
        return;
    }
   
    my $release = esmith::util::determineRelease();

    print $q->p 
        ($q->hr ({-CLASS => "sme-copyrightbar"}), 
        $q->div ({-CLASS => "sme-copyright"},
        "SME Server server ${release}<BR>" .
        "Copyright 1999-2006 Mitel Networks Corporation, Copyright (C) ____COPYYEARS____ Koozali Foundation, Inc..<BR>" .
	"All rights reserved.")
        );

    print '</DIV>';
    print $q->end_html;
}

=pod

=head2 genFooterNoCopyright($q)

=cut

sub genFooterNoCopyright
{
    my ($q) = @_;
    print $q->p ($q->hr);
    print $q->end_html;
}

=pod

=head2 genNavigationFooter($q)

=cut

sub genNavigationFooter
{
    my ($q) = @_;
    print $q->end_html;
}

=pod

=head2 genNoframesFooter($q)

=cut

sub genNoframesFooter
{
    my ($q) = @_;
    print $q->end_html;
}

=pod

=head1 FONT ROUTINES

=head2 curFont()

Returns the preferred font faces eg. "Verdana, Arial, Helvetica, sans-serif".
This should be done by CSS now, so if you're calling this, you shouldn't be.

=cut

sub curFont
{
    return "Verdana, Arial, Helvetica, sans-serif";
}

=pod

=head1 TABLE GENERATION ROUTINES

=head2 genCell($q, $text)

=cut

sub genCell 
{
    my ($q, $text, $class) = @_;

    if ($text =~ /^\s*$/){$text = "&nbsp;"}
    if ($class) { return $q->td({-class => "$class"}, $text),"\n";}
    else { return $q->td ($text),"\n";}
}

=pod

=head2 genDoubleCell($q, $text);

Generates a cell which spans two columns, containing the text specified.

=cut

sub genDoubleCell
{
    my ($q, $text) = @_;
    if ($text =~ /^\s*$/){ $text = "&nbsp;" }
    return $q->td ({colspan => 2}, $text),"\n";
}

=pod

=head2 genSmallCell($q, $text, $type, $colspan)

Generates a cell with "small" text (font size is 80%).
"$type" can be one of: 
"normal" : creates <td class="sme-border"> cell
"header" : creates <th class="sme-border"> cell

=cut

sub genSmallCell
{
    my ($q, $text, $type, $colspan) = @_;
    $text = '' unless defined $text;
    $type ||= 'normal';
    $colspan ||= 1;
    if ($text =~ /^\s*$/){ $text = "&nbsp;" }
    if ("$type" eq "header") {
        return $q->th ({class=>"sme-border", colspan=>$colspan}, $text)."\n";
    } else {
        return $q->td ({class=>"sme-border", colspan=>$colspan}, $text)."\n";
    }        
}

=pod

=head2 genSmallCellCentered($q, $text)

Generates a cell with "small" text (font size is 80%), centered.
creates <td class="sme-border-center"> cell

=cut

sub genSmallCellCentered
{
    my ($q, $text) = @_;
    if ($text =~ /^\s*$/){ $text = "&nbsp;" }
    return $q->td ({class => "sme-border-center"}, $text)."\n";
}

=pod

=head2 genSmallCellRightJustified($q, $text)

=head2 genSmallCellCentered($q, $text)

Generates a cell with "small" text (font size is 80%), right justified.
creates <td class="sme-border-right"> cell

=cut

sub genSmallCellRightJustified
{
    my ($q, $text) = @_;
    if ($text =~ /^\s*$/){ $text = "&nbsp;" }
    return $q->td ({class => "sme-border-right"}, $text)."\n";
}


=pod

=head2 genSmallRedCell($q, $text)

Generates a cell with "small" text (font size is 80%), left justified.
creates <td class="sme-border-warning"> cell

=cut

sub genSmallRedCell
{
    my ($q, $text) = @_;
    if ($text =~ /^\s*$/){ $text = "&nbsp;" }
    return $q->td ({class => "sme-border-warning"}, $text)."\n";
}

=pod

=head2 genTextRow($q, $text)

Returns a table row containing a two-column cell containing $text.

=cut

sub genTextRow
{
    my ($q, $text) = @_;
    if ($text =~ /^\s*$/){ $text = "&nbsp;" }
    return "\n",$q->Tr ($q->td ({colspan => 2}, $text)),"\n";
}

=pod

=head2 genButtonRow($q, $button)

Returns a table row containing an empty first cell and a second cell
containing a button with the value $button.

=cut

sub genButtonRow
{
    my ($q, $button) = @_;

#    return $q->Tr ($q->td ({-class => "sme-submitbutton", -colspan => "2"},$q->b ($button))),"\n";
#    return $q->Tr ($q->td ('&nbsp;'),
#		   $q->td ({-class => "sme-submitbutton"},$q->b ($button))),"\n";
    return $q->Tr ({-class => "sme-layout"}, $q->th ({-class => "sme-layout", colspan => "2"},$q->b ($button))),"\n";
}

=pod

=head2 genNameValueRow($q, $fieldlabel, $fieldname, $fieldvalue)

Returns a table row with two cells.  The first has the text
"$fieldlabel:" in it, and the second has a text field with the default
value $fieldvalue and the name $fieldname.

=cut

sub genNameValueRow
{
    my ($q, $fieldlabel, $fieldname, $fieldvalue) = @_;

    return $q->Tr (
        $q->td ({-class => "sme-noborders-label"}, 
            "$fieldlabel:"),"\n",
	$q->td ({-class => "sme-noborders-content"},
            $q->textfield (
                -name     => $fieldname,
                -override => 1,
                -default  => $fieldvalue,
		-size     => 32))),"\n";
}

=pod

sub genWidgetRow($q, $fieldlabel, $popup)

=cut

# used only by backup panel as far as I can see
sub genWidgetRow
{
    my ($q, $fieldlabel, $popup) = @_;

    return $q->Tr ($q->td ("$fieldlabel:"),
		   $q->td ($popup));
}

=pod 

=head1 STATUS AND ERROR REPORT GENERATION ROUTINES

=head2 genResult($q, $msg)

Generates a "status report" page, including the footer

=cut

sub genResult
{
    my ($q, $msg) = @_;

    print $q->p ($msg);
    genFooter ($q);
}

=pod

=head2 genStateError($q, $confref)

Subroutine to generate "unknown state" error message.

=cut

sub genStateError
{
    my ($q, $confref) = @_;

    genHeaderNonCacheable ($q, $confref, "Internal error");
    genResult ($q, "Internal error! Unknown state: " . $q->param ("state") . ".");
}

END
{
}

#------------------------------------------------------------
# return "1" to make the import process return success
#------------------------------------------------------------

1;

=pod

=head1 AUTHOR

Mitel Networks Corporation

For more information, see http://e-smith.org/

=cut

