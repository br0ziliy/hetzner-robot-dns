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

my $lwp = LWP::UserAgent->new();
$lwp->agent("Mozilla/5.0 (X11; Linux x86_64; rv:7.0.1) Gecko/20100101 Firefox/7.0.1");
$lwp->cookie_jar({});
$lwp->timeout("10");

my $hetzner = "https://robot.your-server.de";
my ($user, $pass, $domainid, $zonefile);

sub mydie {
	my ($mess) = @_;
	print STDERR "ERROR: " . $mess . "\n";
	exit 2;
}

GetOptions (
    'username|user|u=s' => \$user,
    'password|pass|p=s' => \$pass,
    'domainid|domid|d=s' => \$domainid,
    'zonefile|zone|z=s' => \$zonefile
) || mydie("Options missing");
mydie("Username and password required!") unless ($user && $pass);
mydie("No domain ID specified!") unless ($domainid);


sub login {
	if (!$user || !$pass) {
		mydie("Username and password required!");
	}
	print "DEBUG: $user $pass \n";
	my $r = $lwp->post( $hetzner."/login/check",
	        [
	        'user' => $user,
	        'password' => $pass,
	        ],
	        'Referer' => $hetzner."/login",
	        'Cookie' => "robot=2006fe366a925c478835fbfae197fc75",
	);
	print $r->code."\n";
	print "------------------------------------------------\n";
	print $r->headers_as_string."\n";
	print $r->content."\n";
	print "------------------------------------------------\n";
	# Location: https://robot.your-server.de/
	#
}

sub getzone {
	# 432823
	my ($zone) = @_;
	if (!$zone) {
		mydie("Zone ID is required!");
	}
	my $r = $lwp->post ( $hetzner."/dns/update/id/".$zone,
		[],
		Referrer => $hetzner."/dns");
	my $html = $r->content;
	$html =~ m/.*(\$TTL[^<]+)<\/te/;
	my @zone = $1;
	return @zone;
}

sub setzone {
	my ( $id, @zone ) = @_;
	if (!@zone || !$id) {
		mydie("Zone ID is required!");
	}
	#my $zoneescaped = uri_escape(join("",@zone), "^()a-zA-Z0-9\.~\\-_");
	my $zoneescaped = join("",@zone);
	my $r = $lwp->post ( $hetzner."/dns/update",
		[
			'id' => $id,
			'zonefile' => $zoneescaped,
		],
		"Content-Type" => 'application/x-www-form-urlencoded; charset=UTF-8',
		Referrer => $hetzner."/dns",
		"X-Requested-With" => "XMLHttpRequest",
		"X-Prototype-Version" => "1.6.1");
	print $r->code."\n";
	print "------------------------------------------------\n";
	print $r->headers_as_string."\n";
	print $r->content."\n";
	print "------------------------------------------------\n";
	#   <blockquote id="msgbox" class="msgbox_success"><p>Thank you for your order. The DNS entry will be updated now.</p><p>You can keep track of the current status on the <a href="/dns">DNS list</a>.</p></blockquote>
}
login();
if (!$zonefile) {
	my @zone = getzone($domainid);
	my $zonefilename = $domainid.".db";
	open ZONE, '>./'.$zonefilename or die "error opening $zonefilename for writing: $!";
	print ZONE @zone;
	close ZONE;
	print ">>> Edit $zonefilename\n";
} else {
	open ZONE, '<./'.$zonefile or die "error opening $zonefile for reading: $!";
	my @zonecontents = <ZONE>;
	setzone($domainid, @zonecontents);
	close ZONE;
}

