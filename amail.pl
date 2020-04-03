#!/usr/bin/perl

use Env;
use MIME::Lite;
use Getopt::Std;

BEGIN {
    use vars	qw($NAME $DESCRIPTION);
    $NAME		= "amail";
    $DESCRIPTION	= "A Mail Client With A Command Line Interface";
    $LASTMOD		= 20080228;
    $VERSION		= '1.0';

    use vars	qw($SMTP_SERVER $DEFAULT_SENDER $DEFAULT_RECIPIENT $DEFAULT_SUBJECT);
    $SMTP_SERVER	= 'smtp.example.org';
    $DEFAULT_SENDER	= undef;
    $DEFAULT_RECIPIENT	= undef;
    $DEFAULT_SUBJECT	= undef;
    $DEFAULT_BODY	= undef;
}

MIME::Lite->send('smtp', $SMTP_SERVER, Timeout=>60);
my (%o, $msg);

#
# f From:
# t To:
# s Subject:
# b "body text" or "-" for <STDIN>
#
getopts('h:f:t:s:b:', \%o);
$o{f} ||= $DEFAULT_SENDER;
$o{t} ||= $DEFAULT_RECIPIENT;
$o{s} ||= $DEFAULT_SUBJECT;
$o{b} ||= $DEFAULT_BODY;

if ($o{h} || !defined $o{f} || !defined $o{t} || !defined $o{s}) {
    die <<"    HELP_EOF"

    $NAME - $DESCRIPTION
    usage: $0 [-h] [-f from\@domain] [-t to\@domain] 
		[-s "subject text"] [-b "body text" or "-"] [file [file]]

	-h		# This help test
	-f u\@d.com	# The 'From:' e-mail to be sent from
	-t u\@d.com	# The 'To:' e-mail address to send to
	-s "text msg"	# The 'Subject:' text
	-b "text" or -	# The text of the body, or '-' to use <STDIN> standard input
	[file]		# one or more files to attach to this e-mail message

    Examples: # Send a picture of yourself to a friend as an attachment
              Linux\$ $0 -f you\@dom.com -t friend\@dom.com -s "Hello friend" \\
		-b "This is an e-mail message for my friend" \\
		photo/pictureOfMe.jpg

              # pipe text into an e-mail message
              Linux\$ cat /var/log/messages | tail -100 | $0 -f me\@dom.com \\
		-s "last 100 lines of messages log on thissys server" \\
		-t logadmin\@thissys.dom.com -b -

    HELP_EOF
}

$msg = new MIME::Lite(
	From	=> $o{f},
	To	=> $o{t},
	Subject => $o{s},
	Type	=> "multipart/mixed",
);
if ($o{b} eq '-') {
	$msg->attach(
	    Type	=> 'TEXT',
	    Data	=> <STDIN>,
	);
} elsif (defined $o{b}) {
	$msg->attach(
	    Type	=> 'TEXT',
	    Data	=> $o{b},
	);
}
while (@ARGV) {
	$msg->attach(
	    'Type'	=> 'application/octet-stream',
	    'Encoding'	=> 'base64',
	    'Path'	=> shift @ARGV
	);
}
$msg->send('smtp', $SMTP_SERVER);

exit 0;

__END__
