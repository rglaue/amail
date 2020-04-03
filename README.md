# amail

amail - A Mail Client With A Command Line Interface


version 1.1


## Installation

    You will need the following PERL modules installed
     - Env
     - Getopt::Std
     - File::Find
     - File::Basename
     - MIME::Lite
     - Net::SSH
     - Net::SCP
    The modules MIME::Lite, Net::SSH and Net::SCP are probably the only
    ones that do not come with your PERL distribution. To install the
    modules, perform the following at your command prompt:
      linux% perl -MCPAN -e 'install MIME::Lite'
      linux% perl -MCPAN -e 'install Net::SSH'
      linux% perl -MCPAN -e 'install Net::SCP'
    Or if you are using Fedora Core Linux:
      linux% yum install perl-MIME-Lite
      linux% yum install perl-Net-SSH
      linux% yum install perl-Net-SCP


## Execution

    amail - A Mail Client With A Command Line Interface
    usage: ./amail.pl [-h] [-m] [opts] [-c] [opts]
    usage: ./amail.pl [-m] [-f from@domain] [-t to@domain]
        [-s "subject text"] [-b "body text" or "-"]
        [-c] [-d "user@host:/path/to/dest" or "/local/path/dest"]
        [-r "dirpath:filename-regex:filtername"]
        [file [file]]

        -h                # This help test
        -y                # test what would happen in retrieving attachments
        [ mail features ]
        -m                # turn on the mail functionality
        -f 'u@d.com'      # The 'From:' e-mail to be sent from
        -t 'u@d.com'      # The 'To:' e-mail address to send to
        -s "text msg"     # The 'Subject:' text
        -b "text" or -    # The text of the body, or '-' to use <STDIN> standard input
        [ copy features ]
        -c                # turn on the copy functionality
        -d 'u@h:/dest/'   # either a local or ssh destination directory to copy files to
                          # if you use ssh copy, you must have ssh key authentication setup
        [ source file features ]
        -r 'filter'       # a regex type filter of '/path/to/dir:filename-regex;filter-name:filter-options'
                          #   for attaching, or copying, one or more files
        [file]            # one or more files to attach to this e-mail message, and/or copy

    [filters]
        available filters:
            regex        /dir/path:filename-regex;regex:matching-regex-pattern
            stat size    /dir/path:filename-regex;stat:size=[+-=][size in bytes]
            stat atime   /dir/path:filename-regex;stat:atime=[+-=][access time seconds ago]
            stat ctime   /dir/path:filename-regex;stat:ctime=[+-=][creation time seconds ago]
            stat mtime   /dir/path:filename-regex;stat:mtime=[+-=][modification time seconds ago]

    Examples: # Send a picture of yourself to a friend as an attachment
              Linux$ ./amail.pl -f you@dom.com -t friend@dom.com -s "Hello friend" \
                -b "This is an e-mail message for my friend" \
                photo/pictureOfMe.jpg

              # pipe text into an e-mail message
              Linux$ cat /var/log/messages | tail -100 | ./amail.pl -f me@dom.com \
                -s "last 100 lines of messages log on thissys server" \
                -t logadmin@thissys.dom.com -b -

              Linux$ ./amail.pl -f logadmin@thissys.dom.com -t me@dom.com \
                -s "Attached are gziped logfiles smaller than 5000 bytes"
                -r '/var/logs:server\-message\.log\-\d{7,9}\.gz:stat;size=-5000'

    Note: Copy [-c] is performed before and instead of mailing [-m]
