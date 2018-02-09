#!  /usr/bin/perl

package HeadersFromEnvelope;

use strict;
use warnings "all";
use Data::Dumper;
use diagnostics -verbose;
enable diagnostics;

our %LIB;

use constant TRUE  => 1;
use constant FALSE => -1;

our $VERSION = q{0.1.3};
$LIB{'BUILD'}{'Version'} = $VERSION;

$LIB{'BUILD'}{'File'}   = __PACKAGE__;
$LIB{'BUILD'}{'Date'}   = "14\/06\/2011\-13\:00";
$LIB{'BUILD'}{'Author'} = "DAF";
$LIB{'BUILD'}{'Descrip'} =
  __PACKAGE__ . "Set or Add Headers with 'mail from','rcpt to' and/or 'helo' envelope values";
$LIB{'BUILD'}{'Status'}  = "Devel::Beta";
$LIB{'BUILD'}{'AppName'} = __PACKAGE__;

our @changes = ( 'V0.0.1 Initial build', );
our @notes = ( 'Initial build', );

sub HeadersFromEnvelope_mp;

use vars qw/$VERSION @ISA @EXPORT_OK %EXPORT_TAGS/;

@ISA         = 'Exporter';
@EXPORT_OK   = qw/HeadersFromEnvelope_mp/;
%EXPORT_TAGS = ( all => \@EXPORT_OK );

my %HeadersFromEnvelope_dt;

sub HeadersFromEnvelope_mp {

  my $plugcfg = shift;    
  $HeadersFromEnvelope_dt{'retStep'} = 5;
  return (FALSE, \%HeadersFromEnvelope_dt) unless defined $plugcfg;

  my $msg_headers = shift;
  $HeadersFromEnvelope_dt{'retStep'} = 6;
  return (FALSE ,\%HeadersFromEnvelope_dt ) unless defined $msg_headers;

  my $msg_body = shift;
  $HeadersFromEnvelope_dt{'retStep'} = 7;
  return (FALSE ,\%HeadersFromEnvelope_dt ) unless defined $msg_body;

  my $envelope = shift;
  $HeadersFromEnvelope_dt{'retStep'} = 8;
  return (FALSE ,\%HeadersFromEnvelope_dt ) unless defined $envelope;

  $HeadersFromEnvelope_dt{'ForceQuit'} = FALSE;
  $HeadersFromEnvelope_dt{'MsgEdit'} = FALSE;

  $HeadersFromEnvelope_dt{'Always_Put_Headers'} = $plugcfg->val(__PACKAGE__, "Always_Put_Headers") || "no";

  my $header_x_to_re;
  my $header_x_to_match = FALSE;
  my $rcpt_to;

  my $header_x_from_re;
  my $header_x_from_match = FALSE;
  my $mail_from;

  my $header_x_helo_re;
  my $header_x_helo_match = FALSE;
  my $helo;

  $HeadersFromEnvelope_dt{'Header_x_To'} = $plugcfg->val(__PACKAGE__, "Header_x_To") || "";
  if ($HeadersFromEnvelope_dt{'Header_x_To'} ne "") {
    my $re = "^". $HeadersFromEnvelope_dt{'Header_x_To'} . ".*";
    $header_x_to_re=qr/$re/;
    #$header_x_to_match = FALSE;
    ($rcpt_to) = $envelope->{to} =~ /([^<>\s]*@[^<>\s]*)/;
  }

  $HeadersFromEnvelope_dt{'Header_x_From'} = $plugcfg->val(__PACKAGE__, "Header_x_From") || "";
  if ($HeadersFromEnvelope_dt{'Header_x_From'} ne "") {
    my $re = "^". $HeadersFromEnvelope_dt{'Header_x_From'} . ".*";
    $header_x_from_re=qr/$re/;
    #$header_x_from_match = FALSE;
    ($mail_from) = $envelope->{from} =~ /([^<>\s]*@[^<>\s]*)/;
  }

  $HeadersFromEnvelope_dt{'Header_x_Helo'} = $plugcfg->val(__PACKAGE__, "Header_x_Helo") || "";
  if ($HeadersFromEnvelope_dt{'Header_x_Helo'} ne "") {
    my $re = "^". $HeadersFromEnvelope_dt{'Header_x_Helo'} . ".*";
    $header_x_helo_re=qr/$re/;
    #$header_x_helo_match = FALSE;
    $helo = $envelope->{helo};
  }

  return (FALSE ,\%HeadersFromEnvelope_dt) unless ( $HeadersFromEnvelope_dt{'Header_x_To'} ne "" or $HeadersFromEnvelope_dt{'Header_x_From'} ne "" or $HeadersFromEnvelope_dt{'Header_x_Helo'} ne "" );
  
  #..: Read Lines.
  my @temp = (); 
  foreach my $hline (@$msg_headers) {
      
    chomp $hline;

    if ( $HeadersFromEnvelope_dt{'Header_x_To'} ne "" and $hline =~ $header_x_to_re ) {
      $hline = $HeadersFromEnvelope_dt{'Header_x_To'} . " <". $rcpt_to .">"; 
      $header_x_to_match = TRUE;
    }

    if ( $HeadersFromEnvelope_dt{'Header_x_From'} ne "" and $hline =~ $header_x_from_re ) {
      $hline = $HeadersFromEnvelope_dt{'Header_x_From'} . " <". $mail_from .">"; 
      $header_x_from_match = TRUE;
    }

    if ( $HeadersFromEnvelope_dt{'Header_x_Helo'} ne "" and $hline =~ $header_x_helo_re ) {
      $hline = $HeadersFromEnvelope_dt{'Header_x_Helo'} . " <". $helo .">"; 
      $header_x_from_match = TRUE;
    }
    
    push (@temp , $hline); 
  }

  if ( $HeadersFromEnvelope_dt{'Always_Put_Headers'} eq "yes" ) { 

    if ( $HeadersFromEnvelope_dt{'Header_x_To'} ne "" and $header_x_to_match eq FALSE ) {
      push (@temp , $HeadersFromEnvelope_dt{'Header_x_To'} . " <". $rcpt_to .">"); 
    }

    if ( $HeadersFromEnvelope_dt{'Header_x_From'} ne "" and $header_x_from_match eq FALSE ) {
      push (@temp , $HeadersFromEnvelope_dt{'Header_x_From'} . " <". $mail_from .">"); 
    }  

    if ( $HeadersFromEnvelope_dt{'Header_x_Helo'} ne "" and $header_x_helo_match eq FALSE ) {
      push (@temp , $HeadersFromEnvelope_dt{'Header_x_Helo'} . " <". $helo .">"); 
   }
  
  }

  @{$msg_headers} = @temp;

  if ($HeadersFromEnvelope_dt{'Always_Put_Headers'} ne "yes" or $header_x_to_match eq TRUE or  $header_x_from_match eq TRUE or $header_x_from_match eq TRUE) {
    $HeadersFromEnvelope_dt{'MsgEdit'} = TRUE;
  }

  $HeadersFromEnvelope_dt{'retStep'} = 100;
  return ( TRUE, \%HeadersFromEnvelope_dt );

}

1;

