#!/usr/bin/perl

#
## Perl interface for Hetzner DNS management system
##
##
## by Vasyl Kaigorodov <vkaygorodov@gmail.com>
##

use strict;
use LWP::UserAgent;
use Getopt::Long;
use URI::Escape;
use Term::ReadKey;
use Crypt::SSLeay;

# Initialize /browser/
my $lwp = LWP::UserAgent->new();
$lwp->agent("Murzilla/5.0 (X11; Linux x86_64; rv:7.0.1) Gecko/20100101 Firefox/7.0.1");
$lwp->cookie_jar({});
$lwp->timeout("10");

# Basic variables
my $hetzner = "https://robot.your-server.de";
my ($user, $pass, $domainid, $zonefile);

# Parsing command line options
GetOptions (
    'username|user|u=s' => \$user,
    'password|pass|p:s' => \$pass,
    'domainid|domid|d=s' => \$domainid,
    'zonefile|zone|z=s' => \$zonefile
) || mydie("Options missing");
mydie("Username required!") unless ($user);
mydie("No domain ID specified!") unless ($domainid);
getpass() unless ($pass);

# We don't want reveal Hetzner password in 'ps axfuww' output
$0 = "hetzner-robot-dns.pl";

sub mydie {
	my ($mess) = @_;
	print STDERR "ERROR: " . $mess . "\n";
	exit 2;
}

sub getpass {
	ReadMode ('noecho');
	print "Enter Password: ";
	chomp($pass = <STDIN>);
	ReadMode ('restore');
	print "\n";
}

sub login {
	# Extra-check, but I want to be extra-cautious.
	if (!$user || !$pass) {
		mydie("Username and password required!");
	}
	#print "DEBUG: $user $pass \n";

	# Cookie header - is just some MD5 hash, could be anything at the 
	# beginning. Looks like Hetzner expect this cookie to be always set...
	my $r = $lwp->post( $hetzner."/login/check",
	        [
	        'user' => $user,
	        'password' => $pass,
	        ],
	        'Referer' => $hetzner."/login",
	        'Cookie' => "robot=2006fe366a925c478835fbfae197fc75",
	);
	undef $pass;
	#print "DEBUG: ".$r->code."\n";
	#print "DEBUG: ".$r->header('Location')."\n";

	# TODO: Potentially unsafe - but I don't know other method to realibly detect
	# a successful login.
	if ($r->code != 302 && $r->header('Location') ne 'https://robot.your-server.de/') {
		return 1;
	} else {
		return 0;
	}
}

sub getzone {
	my ($zoneid) = @_;

	# Another extra-check - should never happen.
	if (!$zoneid) {
		mydie("Zone ID is required!");
	}
	my $r = $lwp->post( $hetzner."/dns/update/id/".$zoneid,
		[],
		Referrer => $hetzner."/dns");
	my $html = $r->content;

	# TODO: Potentially unsafe regexp - but what can we do ...
	$html =~ m/.*(\$TTL[^<]+)<\/te/;
	my @zone = $1;
	return @zone;
}

sub setzone {
	my ( $id, @zone ) = @_;

	# TODO: check zone file @zone for sanity?

	# One more extra-check - see, I'm cautious :)
	if (!@zone || !$id) {
		mydie("Zone ID is required!");
	}
	my $zoneescaped = join("",@zone);

	# X- headers should be there probably - without these guys
	# Hetzner just ignore the POST request.
	my $r = $lwp->post ( $hetzner."/dns/update",
		[
			'id' => $id,
			'zonefile' => $zoneescaped,
		],
		"Content-Type" => 'application/x-www-form-urlencoded; charset=UTF-8',
		Referrer => $hetzner."/dns",
		"X-Requested-With" => "XMLHttpRequest",
		"X-Prototype-Version" => "1.6.1");

	# TODO: Potentially unsafe - first thing to look at if setzone() fails
	if ($r->content !~ /The\ DNS\ entry\ will\ be\ updated\ now/) {
		#print "DEBUG: ".$r->headers_as_string."\n----\n";
		#print "DEBUG: ".$r->content."\n";
		mydie("Updating zone ".$id." failed. Hetzner said: ".$r->code);
	} else {
		return 0;
	}
}
if (login()) {
	mydie("Was not able to login to Hetzner!");
}
if (!$zonefile) {
	my @zone = getzone($domainid);
	my $zonefilename = $domainid.".db";
	open ZONE, '>./'.$zonefilename or die "error opening $zonefilename for writing: $!";
	print ZONE @zone;
	close ZONE;
	print "$zonefilename\n";
} else {
	open ZONE, '<./'.$zonefile or die "error opening $zonefile for reading: $!";
	my @zonecontents = <ZONE>;
	setzone($domainid, @zonecontents);
	close ZONE;
}
