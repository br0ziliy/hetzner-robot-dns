Hetzner Robot DNS
=================

Perl interface for Hetzner DNS management system
by Vasyl Kaigorodov <vkaygorodov@gmail.com>

Hetzner API does not provide interface to deal with DNS zones - so here be dragons.

Disclaimer
==========

Script is provided AS IS, author takes absolutely no responsibility for any harm, downtime or revenue lost as a consequence of this script usage.

Usage
=====

Main culprit is that you need to find out the zone ID number.
To do this, go to https://robot.your-server.de/dns .
Select "View page source" in your browser and find a block similar to this:

```html
<table class="box_title" onclick="javascript:expandBox(this, 'data_123456', '/dns/update/id/123456', '123456');">
<tr><td class="title">domain.com</td>
```

(Firebug might be useful here also)
Note the **/dns/update/id/123456** part - you need the numbers at the end of string (here: 123456).

Now run the script as below:

    $ hetzner-robot-dns.pl -u <hetzner_user> -p <hetzner_password> -d <domain_id>

Don't forget to replace **<hetzner_user>** and **<hetzner_password>** accordingly.
You can prefer not to specify your password on the command line - then run script like this:

    $ hetzner-robot-dns.pl -u <hetzner_user> -p -d <domain_id>

Script will ask for a password then.
When script finishes - it will print out just one line, representing a file which now contains the whole DNS zone:

    $ hetzner-robot-dns.pl -u hetzneruser -p dragons -d 123456
    123456.db

Edit that file, and upload it back to Hetzner:

    $ hetzner-robot-dns.pl -u hetzneruser -p dragons -d 123456 -z 123456.db

Please note, that there're no sanity checks made (yet) on the supplied zonefile, it will be sent to Hetzner as-is - so it's up to you to update it carefully, or you in risk of messing up your DNS zone.
