#!/usr/bin/perl -T

use lib qw(/MTA/appn/lib/PDist);

package CFilterD::Server;

use strict;
use IO::File;
#use IO::Socket;

sub new {
	
# This now emulates Net::SMTP::Server::Client for use with Net::Server which
# passes an already open socket.

    my($this, $socket) = @_;
    
    my $class = ref($this) || $this;
    my $self = {};
    $self->{sock} = $socket;
    
    bless($self, $class);
    
    die "$0: socket bind failure: $!\n" unless defined $self->{sock};
    $self->{state} = 'started';
    $self->{rcpt_to_command_extras} = "";
    return $self;
 
    
}


sub chat {
    my ($self) = @_;
    local(*_);
    if ($self->{state} !~ /^data/i) {
		return 0 unless defined($_ = $self->_getline);
		s/[\r\n]*$//;
		$self->{state} = $_;
		if (s/^.?he?lo\s+//i) {  # mp: find helo|ehlo|lhlo
			# mp: determine protocol (for future use)
			if ( /^L/i ) { 
				$self->{proto} = "lmtp";
			} elsif ( /^E/i ) { 
    			$self->{proto} = "esmtp"; 
			} else { 
    			$self->{proto} = "smtp"; }
		    s/\s*$//;
		    s/\s+/ /g;
		    $self->{helo} = $_;
		    $self->{envelope}->{helo} = $_;
		} elsif (s/^rset\s*//i) {
		    delete $self->{to};
		    #delete $self->{data};
		    @{$self->{headers}} = (); delete $self->{headers};
		    @{$self->{body}} = (); delete $self->{body};
		    delete $self->{recipients};
		} elsif (s/^mail\s+from:\s*//i) {
		    delete $self->{to};
		    #delete $self->{data};
		    @{$self->{headers}} = (); delete $self->{headers};
		    @{$self->{body}} = (); delete $self->{body};	    
		    delete $self->{recipients};
		    s/\s*$//;
		    $self->{from} = $_;
		    $self->{envelope}->{from} = $_;
		} elsif (s/^rcpt\s+to:\s*//i) {
		    s/\s*$//; s/\s+/ /g;
		    $self->{to} = $_;
		    $self->{envelope}->{to} = $_;
		    push @{$self->{recipients}}, $_;
		    if(defined($self->{rcpt_to_command_extras}) and  $self->{rcpt_to_command_extras} ne "") { $self->{state} .= " " . $self->{rcpt_to_command_extras}; }
		} elsif (/^data/i) {
		    $self->{to} = $self->{recipients};
		}
    } else {
#		if (defined($self->{data})) {
#		    $self->{data}->seek(0, 0);
#		    $self->{data}->truncate(0);
#		} else {
#		    $self->{data} = IO::File->new_tmpfile;
#		}
		@{$self->{headers}} = ();
		@{$self->{body}} = ();		    		

		my $is_bd = 0;
		while (defined($_ = $self->_getline)) {
			
		    if($is_bd eq 0  and $_ =~ /^\r?\n?$/) { $is_bd=1; next;}
			
			
		    if ($_ eq ".\r\n") {
			  #$self->{data}->seek(0,0);
			  return $self->{state} = '.';
		    }
		    s/^\.\./\./;		   

		    #$self->{data}->print($_) or die "$0: write error saving data\n";		    
		    chomp;
		    if($is_bd) {		    	
		    	push( @{$self->{body}}, $_);
		    }
		    else {		    	
		    	push( @{$self->{headers}}, $_);
		    }
		    
		}
		return(0);
    }
    return $self->{state};
}


sub ok {
    my ($self, @msg) = @_;
    @msg = ("250 ok.") unless @msg;
    $self->_print("@msg\r\n") or
	  die "$0: write error acknowledging $self->{state}: $!\n";
}


sub fail {
    my ($self, @msg) = @_;
    @msg = ("550 no.") unless @msg;
    $self->_print("@msg\r\n") or
	  die "$0: write error acknowledging $self->{state}: $!\n";
}

# utility functions

sub _getline {
    my ($self) = @_;
    local ($/) = "\r\n";
    my $tmp = $self->{sock}->getline;
    if ( defined $self->{debug} ) {
      $self->{debug}->print($tmp) if ($tmp);
    }
    return $tmp;
}

sub _print {
    my ($self, @msg) = @_;
    $self->{debug}->print(@msg) if defined $self->{debug};
    $self->{sock}->print(@msg);
}

1;

################################################################################
package CFilterD::Client;

use strict;
use IO::Socket;

sub new {
    my ($this, @opts) = @_;
    my $class = ref($this) || $this;
    my $self = bless { timeout => 300, @opts }, $class;
    $self->{sock} = IO::Socket::INET->new(
			PeerAddr => $self->{interface},
			PeerPort => $self->{port},
			Timeout => $self->{timeout},
			Proto => 'tcp',
			Type => SOCK_STREAM,
	    );
    die "$0: socket connect failure: $!\n" unless defined $self->{sock};
    return $self;
}


sub hear {
    my ($self) = @_;
    my ($tmp, $reply);
    return undef unless $tmp = $self->{sock}->getline;
    while ($tmp =~ /^\d{3}-/) {
		$reply .= $tmp;
		return undef unless $tmp = $self->{sock}->getline;
    }
    $reply .= $tmp;
    $reply =~ s/\r\n$//;
    return $reply;
}


sub say {
    my ($self, @msg) = @_;
    return unless @msg;
    $self->{sock}->print("@msg", "\r\n") or die "$0: write error: $!";
}


#DAF: escribe el mensaje en el socket....
sub yammer { 
    #my ($self, $fh) = (@_);
    my ($self, $headers, $body) = (@_);

    local (*_);
    local ($/) = "\r\n";
    $self->{sock}->autoflush(0);  # use less writes (thx to Sam Horrocks for the tip)
#    while (<$fh>) {
#	  s/^\./../;
#	  $self->{sock}->print($_) or die "$0: write error: $!\n";
#    }
 
    foreach my $line (@$headers) {
	  #s/^\./../;
	  $line =~ s/^\./../;
	  $self->{sock}->print("$line\r\n") or die "$0: write error: $!\n";    	
    }
    
    $self->{sock}->print("\r\n"); #blank line: seeparates headers and body.
    
    foreach my $line (@$body) {
	  #s/^\./../;
	  $line =~ s/^\./../;
	  $self->{sock}->print("$line\r\n") or die "$0: write error: $!\n";    	
    }
 
    $self->{sock}->autoflush(1);  # restore unbuffered socket operation
    $self->{sock}->print(".\r\n") or die "$0: write error: $!\n";
}

1;


################################################################################
package CFilterD;

use strict;
use Net::Server::PreForkSimple;
use IO::File;
use Getopt::Long;

use Config::IniFiles;
#use Data::Dumper; #for debug/development

BEGIN {
  # Load Time::HiRes if it's available
  eval { require Time::HiRes };
  Time::HiRes->import( qw(time) ) unless $@;  
  
  # use included modules
  import CFilterD::Server;
  import CFilterD::Client;
  
  
}

use constant TRUE  => 1;
use constant FALSE => -1;
use vars qw(@ISA $VERSION);
our @ISA = qw(Net::Server::PreForkSimple);
our $VERSION = '2.30';


my $PlugCfg;
my @MailParsers;
my @FuncParsers; 
my $plug_ctr;
my @Plugins;
my $Ret_ref;
my $Call_stat;
my $itctr;



sub process_message {
	
	#my ($self, $fh) = @_;
	my ($self, $headers, $body, $envelope) = @_;
	
	# output lists with a , delimeter by default
	local ($") = ",";
	
	# start a timer
	my $start = time;

    # this gets info about the message temp file
    #(my $dev,my $ino,my $mode,my $nlink,my $uid, my $gid,my $rdev,my $size, my $atime,
    # my $mtime,my $ctime, my $blksize,my $blocks) = $fh->stat or die "Can't stat mail file: $!";    
    die "Can't stat mail contents: $!" if(not @$headers);
    
	    
	my ($msgid, $sender, $recips, $tmp, $mail, $msg_resp);
	    
	my $inhdr = 1;
	my $envfrom = 0;
	my $envto = 0;
	my $addedenvto = 0;
	    
	$recips = "@{$self->{smtp_server}->{to}}";
	if ("$self->{smtp_server}->{from}" =~ /(\<.*?\>)/ ) {$sender = $1;}
	$recips ||= "(unknown)";
	$sender ||= "(unknown)";
	    
	## read message into array of lines to feed to SA (OJO DAF:)
	    
	# loop over message file content
#    $fh->seek(0,0) or die "Can't rewind message file: $!";
#    while (<$fh>) { 
#		if (/^\r?\n?$/) {
#			$self->log(2, "%s", "EOH detected...");
#			last;
#		}
#		chomp;
#		push(@msgheaders, $_);
#		# find the Message-ID for logging (code is mostly from spamd)
#		# DAF: generic $msgid sanitize		
#		if ( $inhdr && /^Message-Id:\s+(.*?)\s*$/i ) {
#			$msgid = $1;
#			while ( $msgid =~ s/\([^\(\)]*\)// ) { } # remove comments and
#			$msgid =~ s/^\s+|\s+$//g;          # leading and trailing spaces
#			$msgid =~ s/\s+/ /g;               # collapse whitespaces
#			$msgid =~ s/^.*?<(.*?)>.*$/$1/;    # keep only the id itself
#			$msgid =~ s/[^\x21-\x7e]/?/g;      # replace all weird chars
#			$msgid =~ s/[<>]/?/g;              # plus all dangling angle brackets
#			$msgid =~ s/^(.+)$/<$1>/;          # re-bracket the id (if not empty)
#		}
#	}
#
#    while (<$fh>) { 
#		chomp;
#		push(@msgbody, $_);
#    }

	foreach my $hdr (@$headers) {
		if ($hdr =~ /^Message-Id:\s+(.*?)\s*$/i ) {
			$msgid = $1;
			while ( $msgid =~ s/\([^\(\)]*\)// ) { } # remove comments and
			$msgid =~ s/^\s+|\s+$//g;          # leading and trailing spaces
			$msgid =~ s/\s+/ /g;               # collapse whitespaces
			$msgid =~ s/^.*?<(.*?)>.*$/$1/;    # keep only the id itself
			$msgid =~ s/[^\x21-\x7e]/?/g;      # replace all weird chars
			$msgid =~ s/[<>]/?/g;              # plus all dangling angle brackets
			$msgid =~ s/^(.+)$/<$1>/;          # re-bracket the id (if not empty)
		}
	}
	$self->log(2, "%s", "processing message $msgid for $recips");

	eval {
			
		local $SIG{ALRM} = sub { die "Timed out!\n" };
		# save previous timer and start new
		my $previous_alarm = alarm($self->{cfilterd}->{plugtimeout}); 
		
	
		#for debug
		if ( $self->{cfilterd}->{debug} ) {
			open FL, ">>/MTA/appn/cfplugres.log"; 
    			print FL "ES ORIGINAL\n";
    			foreach my $qline (@$headers) { print FL "$qline\n"; }
    			foreach my $qline (@$body) { print FL "$qline\n"; }
    			print FL "----------------\n";
        		close FL;
		}
		
		
		# Apply plugins to the message
		foreach my $ParName (@FuncParsers) {

			my $par_stat = sprintf( "%s", $self->{cfilterd}->{plugcfg}->val( q{Plugins}, q{MP_} . $ParName ) );
	    	if ( ($par_stat eq q{activated}) and (not defined(${$Ret_ref}{'ForceQuit'}) or ${$Ret_ref}{'ForceQuit'} == FALSE) ) {
				 my $proc = $ParName . q{::} . $ParName . q{_mp};                        
	            ( $Call_stat, $Ret_ref ) = &{ \&$proc }( $self->{cfilterd}->{plugcfg}, $headers, $body, $envelope);	            
	                #for debug
		    if ( $self->{cfilterd}->{debug} ) {
    				open FL, ">>/MTA/appn/cfplugres.log"; 
    				print FL "ES $proc\n";
    				foreach my $qline (@$headers) { print FL "$qline\n";}
    				foreach my $qline (@$body) { print FL "$qline\n";}
    				print FL "----------------\n";
    				close FL;
		   }
	            
	       if ( not defined $Call_stat ) { $Call_stat = FALSE; }
	                        
		   if ( $Call_stat != TRUE && ${$Ret_ref}{'retStep'} != 100){
					$self->log(2, "%s", "Error Status returned by function : $proc returned value : ". ${$Ret_ref}{'retStep'});
		   }
	
			if ( $Call_stat == TRUE ) {
					if ( $self->{cfilterd}->{debug} ) {
			  			$self->log(2, "Ok: processing message by $proc: MsgEdit=#". ${$Ret_ref}{'MsgEdit'} ."# ForceQuit=#". ${$Ret_ref}{'ForceQuit'} ."#");
		  			}
				}
			}
		}
			
		$self->log(2, "Applied plugins to the message");

		
#		# Build the new message to relay
#		# pause the timeout alarm while we do this (no point in timing
#		# out here and leaving a half-written file).		
#		my $pause_alarm = alarm(0);
#
#		$fh->truncate(0) or die "Can't truncate message file: $!";
#
#		my $arraycont = @$headers; 
#		for ( 0..($arraycont-1) ) {  
#			$fh->print($msgheaders[$_] . "\r\n")  or die "Can't print to message file: $!"; 
#		}
#		#$fh->print("\r\n"); #blank line: seeparates headers and body.
#		$fh->print("\n"); #blank line: seeparates headers and body.
#		$arraycont = @msgbody; 
#		for ( 0..($arraycont-1) ) {  
#			$fh->print($msgbody[$_] . "\r\n")  or die "Can't print to message file: $!"; 
#		}
#
#
#
#		#restart the alarm
#	    alarm($pause_alarm);
    
		 #FINISH!!!
	     # set the timeout alarm back to wherever it was at
	     alarm($previous_alarm);
	   
	};
	
	if ( $@ ne '' ) {
		$self->log(1, "%s", "WARNING!! Content Filter error on message $msgid: $@");
      		return 0;
	}
	    
	return 1;

}




sub process_request {
  my $self = shift;
  my $msg;
  	
  eval {
	
	local $SIG{ALRM} = sub { die "Child server process timed out!\n" };
	my $timeout = $self->{cfilterd}->{childtimeout};
	
	# start a timeout alarm  
	alarm($timeout);
	
	# start an smtp server
	#$self->{server}->{client}->{rcpt_to_command_extras} = $self->{cfilterd}->{rcpt_to_command_extras};
	my $smtp_server = CFilterD::Server->new($self->{server}->{client});

	unless ( defined $smtp_server ) {
	  die "Failed to create listening Server: $!"; }
	  
	$smtp_server->{rcpt_to_command_extras} = $self->{cfilterd}->{rcpt_to_command_extras};

	$self->{smtp_server} = $smtp_server;
	
	if ( $self->{cfilterd}->{debug} ) {
	  $self->log(2, "Initiated Server"); }
	    
	# start an smtp "client" (really a sending server)
	my $client = CFilterD::Client->new(interface => $self->{cfilterd}->{relayhost}, 
					   port => $self->{cfilterd}->{relayport});
	unless ( defined $client ) {
	  die "Failed to create sending Client: $!"; }

	if ( $self->{cfilterd}->{debug} ) {
	  $self->log(2, "Initiated Client"); }
	    
	# pass on initial client response
	# $client->hear can handle multiline responses so no need to loop
	$smtp_server->ok($client->hear)
		or die "Error in initial server->ok(client->hear): $!";
		
	if ( $self->{cfilterd}->{debug} ) {
	  $self->log(2, "smtp_server state: '" . $smtp_server->{state} . "'"); }
	  
	# while loop over incoming data from the server
	while ( my $what = $smtp_server->chat ) {
	  
	  if ( $self->{cfilterd}->{debug} ) {
	    $self->log(2, "smtp_server state: '" . $smtp_server->{state} . "'"); }
		
	  # until end of DATA is sent, just pass the commands on transparently
	  if ($what ne '.') {
		  
	    $client->say($what)
		  or die "Failure in client->say(what): $!";
		
	  # but once the data is sent now we want to process it
	  } else {

		# message checking routine - message might be rewritten here
	    #my $pmrescode = $self->process_message($smtp_server->{data});
	    my $pmrescode = $self->process_message($smtp_server->{headers}, $smtp_server->{body},  $smtp_server->{envelope});
	    
	    # pass on the messsage if exit code <> 0 or die-on-plugin-errors flag is off
	    if ( $pmrescode or !$self->{cfilterd}->{dope} ) {
		    
		    # need to give the client a rewound file
		    #$smtp_server->{data}->seek(0,0)
			#	or die "Can't rewind mail file: $!";
		    
		    # now send the data on through the client
		    #$client->yammer($smtp_server->{data})
		    $client->yammer($smtp_server->{headers}, $smtp_server->{body})
			  or die "Failure in client->yammer(smtp_server->{data}): $!";
			  
		} else {
			
			$smtp_server->ok("450 Temporary failure processing message, please try again later");
			last;
		}
		
		#close the temp file
		#$smtp_server->{data}->close
		#	or $self->log(1, "%s", "WARNING!! Couldn't close smtp_server->{data} temp file: $!");
		@{$smtp_server->{headers}} = ();
		@{$smtp_server->{body}} = ();

	    if ( $self->{cfilterd}->{debug} ) {
	      $self->log(2, "Finished sending DATA"); }
	  }

	  # pass on whatever the relayhost said in response
	  # $client->hear can handle multiline responses so no need to loop
	  my $destresp = $client->hear;
	  $smtp_server->ok($destresp)
		or die "Error in server->ok(client->hear): $!";
		
	  if ( $self->{cfilterd}->{debug} ) {
	    $self->log(2, "%s", "Destination response: '" . $destresp . "'"); }
	  
	  # if we're in data state but the response is an error, exit data state.
	  # Shold not normally occur, but can happen. Thanks to Rodrigo Ventura for bug reports.
	  if ( $smtp_server->{state} =~ /^data/i and $destresp  =~ /^[45]\d{2} / ) {
		$smtp_server->{state} = "err_after_data";
		if ( $self->{cfilterd}->{debug} ) {
		  $self->log(2, "Destination response indicates error after DATA command"); }
	  }

	  # restart the timeout alarm  
	  alarm($timeout);
		
	} # server ends connection

    # close connections
    $client->{sock}->close
			or die "Couldn't close client->{sock}: $!";
    $smtp_server->{sock}->close
			or die "Couldn't close smtp_server->{sock}: $!";

	if ( $self->{cfilterd}->{debug} ) {
	  $self->log(2, "Closed connections"); }
	    
  }; # end eval block
  
  alarm(0);  # stop the timer
  # check for error in eval block
  if ($@ ne '') {
	  chomp($@);
	  $msg = "WARNING!! Error in process_request eval block: $@";
	  $self->log(0, "%s", $msg);
	  die ($msg . "\n");
  }
  
  $self->{cfilterd}->{instance}++;
  
}

# Net::Server hook
# about to exit child process
sub child_finish_hook {
    my($self) = shift;
	if ( $self->{cfilterd}->{debug} ) {
		$self->log(2, "Exiting child process after handling ". 
	                  $self->{cfilterd}->{instance} ." requests"); }
}


sub is_int {
   defined $_[0] && $_[0] =~ /^[+-]?\d+$/;
}



###### MAIN #####
#for debug/development
#$Data::Dumper::Sortkeys = 1; #Sort the keys in the output
#$Data::Dumper::Deepcopy = 1; #Enable deep copies of structures
#$Data::Dumper::Indent = 2; #Output in a reasonable style (but no array indexes)

my $config = $ARGV[0];
my ($n, $configfile) = split(/=/, $config);
die ("config parameter is mandatory") if $configfile eq "";
if ( $n eq "--config" and $configfile ne "") {
	die "Cannot read config file $configfile" if (not -e $configfile);
}

my $PlugCfg = new Config::IniFiles( -file => $configfile );
my ($relayhost, $relayport, $host, $port, $children, $maxrequests, $childtimeout, $plugtimeout, $pidfile, $user, $group, $debug, $logsock, $nsloglevel, $dope, $background, $rcpt_to_command_extras);
my @params = $PlugCfg->Parameters(q{General});
foreach my $param (@params) {
	my $val = $PlugCfg->val( q{General}, $param);
	my $set = "";
	if (is_int $val) { 
		$set = '$'.$param ." = ". $PlugCfg->val( q{General}, $param) .";";
	}
	else {
		$set = '$'.$param ." =\"". $PlugCfg->val( q{General}, $param) ."\";";
	}
	eval $set;
}


my $plug_ctr = 0;

my %options = (
	       config => \$configfile,
	       port => \$port,
	       host => \$host,
	       relayhost => \$relayhost,
	       relayport => \$relayport,
	       pid => \$pidfile,
	       user => \$user,
	       group => \$group,
	       maxrequests => \$maxrequests,
	       childtimeout => \$childtimeout,
	       plugtimeout => \$plugtimeout,
	       children => \$children,
	       logsock => \$logsock,
	      );

usage(1) unless GetOptions(\%options,
		   'config=s',
		   'port=i',
		   'host=s',
		   'relayhost=s',
		   'relayport=i',
		   'children|c=i',
		   'maxrequests|mr=i',
		   'childtimeout=i',
		   'plugtimeout=i',
		   'user|u=s',
		   'group|g=s',
		   'pid|p=s',
		   'debug|d',
		   'help|h|?',
		   'dope',
		   'logsock=s',
		   'nodetach',
		   );

usage(0) if $options{help};

if ( $logsock !~ /^(unix|inet)$/ ) {
	print "--logsock parameter needs to be either unix or inet\n\n";
	usage(0);
}

if ( $options{debug} ) { $debug = 1; $nsloglevel = 4; }
if ( $options{dope} ) { $dope = 1; }
if ( $options{'nodetach'} ) { $background = undef; }

if ( $children < 1 ) { print "Option --children must be greater than zero!\n"; exit shift; }


my @tmp = split (/:/, $relayhost);
$relayhost = $tmp[0];
if ( $tmp[1] ) { $relayport = $tmp[1]; }

@tmp = split (/:/, $host);
$host = $tmp[0];
if ( $tmp[1] ) { $port = $tmp[1]; }





my $plug_ctr = 0;
my @Plugins = $PlugCfg->Parameters(q{Plugins});
foreach my $plug (@Plugins) {
	if ( $plug =~ m/^(MP_)/ ) {
		$MailParsers[$plug_ctr] = $plug;
		$plug =~ s/^(MP_)//;
		$FuncParsers[$plug_ctr] = $plug;
		$plug_ctr++;
	}
}


#. Check main function.
use lib q{/MTA/appn/lib/cfilterd/plug};
foreach my $fpar (@FuncParsers) {
    next unless defined $fpar;
    my $par_stat = sprintf( "%s", $PlugCfg->val( q{Plugins}, q{MP_} . $fpar ) );
    if ( $par_stat eq q{activated} ) {
        
        #Good!!!
        require $fpar . q{.pm};
                
        my $tst_stat;
        my $tst_ret_ref;
        my $tst_func = $fpar . q{::} . $fpar . q{_mp};
	if($debug) { print "Plugin Function: $tst_func:";}
        eval{
         ( $tst_stat, $tst_ret_ref ) = &{ \&$tst_func }
        };
        
        if ( not defined $tst_stat){
        	die("Error accesing plugin function: $tst_func");			
		}
		else {
			#push(@FuncParsers, $fpar);		
			if($debug) { print ": IS ACTIVE ($tst_stat)...\n"; }
		}
		
    }
}




my $server = bless {
    server => {host => $host,
				port => [ $port ],
				log_file => 'Sys::Syslog',
				log_level => $nsloglevel,
				syslog_logsock => $logsock,
				syslog_ident => 'cfilterd',
				syslog_facility => 'mail',
				background => $background,
				pid_file => $pidfile,
				user => $user,
				group => $group,
				max_servers => $children,
				max_requests => $maxrequests,
		      },
    cfilterd => { relayhost => $relayhost,
				relayport => $relayport,
				childtimeout => $childtimeout,
				plugtimeout => $plugtimeout,
				debug => $debug,
				dope => $dope,
				instance => 0,
				plugcfg => $PlugCfg,
				rcpt_to_command_extras => $rcpt_to_command_extras,
			   },
   }, 'CFilterD';

# Redirect all warnings to Server::log 
$SIG{__WARN__} = sub { $server->log (2, "%s", $_[0]); };
	   
# call Net::Server to start up the daemon inside
$server->run;

exit 1;  # shouldn't get here

sub usage {
  print <<EOF ;
usage: $0 [ options ]

Options:

  --config=config_file	   Path to config file (in this version is mandatory)
  
  --host=host[:port]       Hostname/IP and optional port to listen on. Default is 127.0.0.1 port 10025
  
  --port=n                 Port to listen on (alternate syntax to above).
  
  --relayhost=host[:port]  Host to relay mail to. Default is 127.0.0.1 port 25.
  
  --relayport=n            Port to relay to (alternate syntax to above).
  
  --children=n             Number of child processes (servers) to start and keep running. Default is 5 (plus 1 parent proc).
  
  --maxrequests=n          Maximum requests that each child can process before exiting. Default is 20.
  
  --childtimeout=n         Time out children after this many seconds during transactions 
                              (each S/LMTP command including the time it takes to send the data).
                              Default is 360 seconds (6min).
  
  --plugtimeout=n          Time out of plugins after this many seconds. Default is 285 seconds.
                               
  --pid=filename           Store the daemon's process ID in this file.
  
  --user=username          Specifies the user that the daemon runs as.
                               
  --group=groupname        Specifies the group that the daemon runs as.
                               
  --nodetach               Don't detach from the console and fork into background.
                               
  --logsock=inet or unix   Allows specifying the syslog socket type. Default is 'unix'.

  --dope                   (d)ie (o)n (p)lugins (e)rrors. If this is specified and plugin times out or throws an error,
                               the mail will be rejected with a 450 temporary error message. 
                               Default is to pass through email even in the event of an plugin problem.
                                                                                        	    					     
  --debug or -d            Turn on cfilterd debugging (sent to log file).
						   
  --help or -h or -?       This message
  
EOF


  exit shift;
}

__END__

