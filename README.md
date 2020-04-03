# amail

amail - A Mail Client With A Command Line Interface


version 1.0


## Installation

    You will need the following PERL modules installed
     - Env;
     - MIME::Lite;
     - Getopt::Std;
    The module MIME::Lite is probably the only one that does not come with
    your PERL distribution. To install the module, perform the following
    at your command prompt:
      linux% perl -MCPAN -e 'install MIME::Lite'
    Or if you are using Fedora Core Linux:
      linux% yum install perl-MIME-Lite


## Execution

    amail - A Mail Client With A Command Line Interface
    usage: ./amail.pl [-h] [-f from@domain] [-t to@domain] 
		[-s "subject text"] [-b "body text" or "-"] [file [file]]

	-h		# This help test
	-f u@d.com	# The 'From:' e-mail to be sent from
	-t u@d.com	# The 'To:' e-mail address to send to
	-s "text msg"	# The 'Subject:' text
	-b "text" or -	# The text of the body, or '-' to use <STDIN> standard input
	[file]		# one or more files to attach to this e-mail message

    Examples: # Send a picture of yourself to a friend as an attachment
              Linux$ ./amail.pl -f you@dom.com -t friend@dom.com -s "Hello friend" \
		-b "This is an e-mail message for my friend" \
		photo/pictureOfMe.jpg

              # pipe text into an e-mail message
              Linux$ cat /var/log/messages | tail -100 | ./amail.pl -f me@dom.com \
		-s "last 100 lines of messages log on thissys server" \
		-t logadmin@thissys.dom.com -b -
