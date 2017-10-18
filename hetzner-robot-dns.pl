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
use HTML::Entities;
use warnings;

# Generate a random string for PHPSessionID
my @set = ('0' ..'9', 'A' .. 'F');
my $phpsess = join '' => map $set[rand @set], 1 .. 32;

# Initialize /browser/
my $lwp = LWP::UserAgent->new();
$lwp->agent("Murzilla/5.0 (X11; Linux x86_64; rv:7.0.1) Gecko/20100101 Firefox/7.0.1");
$lwp->cookie_jar({});
$lwp->timeout("10");

# Basic variables
my $hetzner = "https://accounts.hetzner.com";
my $hetzner2 = "https://robot.your-server.de";
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
    my $r = $lwp->post( $hetzner."/login_check",
            [
            '_username' => $user,
            '_password' => $pass,
            ],
             'Cookie' => "PHPSESSID=".$phpsess.";"
    );
    undef $pass;
    #print "DEBUG: ".$r->code."\n";
    #print "DEBUG: ".$r->header('Location')."\n";

    # TODO: Potentially unsafe - but I don't know other method to realibly detect
    # a successful login.
    if ($r->code != 302 && $r->header('Location') ne $hetzner.'/') {
        return 1;
    } else {
my $r1 = $lwp->get( $hetzner2 );
        return 0;
    }
}

sub getcsrf {
       my $url = shift;
       my $r = $lwp->post ($url);
      # print "DEBUG2: ".$r->content."\n";
       if ($r->content =~ /name="_csrf_token"\s+value="([a-f0-9]+)"/) {
               #print "DEBUG: CSRF token - " . $1;
               return $1;
       } else {
               mydie("CSRF token not found, exiting.");
       }
}

sub getzone {
    my ($zoneid) = @_;

    # Another extra-check - should never happen.
    if (!$zoneid) {
        mydie("Zone ID is required!");
    }
    my $r = $lwp->post( $hetzner2."/dns/update/id/".$zoneid,
        [],
        Referrer => $hetzner2."/dns");
    my $html = $r->content;

    # TODO: Potentially unsafe regexp - but what can we do ...
    $html =~ m/.*(\$TTL[^<]+)<\/te/;
    # decode_entities() is exported from HTML::Entities
    my @zone = decode_entities($1);
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
    my $csrf = getcsrf($hetzner2."/dns/update/id/".$id);
    my $r = $lwp->post ( $hetzner2."/dns/update",
        [
            'id' => $id,
            'zonefile' => $zoneescaped,
            '_csrf_token' => $csrf,
        ],
        "Content-Type" => 'application/x-www-form-urlencoded; charset=UTF-8',
        Referrer => $hetzner2."/dns",
        "X-Requested-With" => "XMLHttpRequest",
        "X-Prototype-Version" => "1.6.1");

    # TODO: Potentially unsafe - first thing to look at if setzone() fails
    if ($r->content !~ /The\ DNS\ entry\ will\ be\ updated\ now/ && $r->content !~ /Der\ DNS-Eintrag\ wird\ nun\ ge/ ) {
        #print "DEBUG: ".$r->headers_as_string."\n----\n";
        #print "DEBUG: ".$r->content."\n";
        mydie("Updating zone ".$id." failed. Hetzner said: ".$r->code);
    } else {
        print "UPDATING zone ".$id." successful.\n";
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
    open ZONE, '<'.$zonefile or die "error opening $zonefile for reading: $!";
    my @zonecontents = <ZONE>;
    setzone($domainid, @zonecontents);
    close ZONE;
}
