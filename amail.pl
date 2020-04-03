#!/usr/bin/perl

use Getopt::Std;
use File::Find;

use Env;
use MIME::Lite;

use Net::SSH(sshopen3);
use Net::SCP;
use File::Basename;

BEGIN {
    use vars            qw($NAME $DESCRIPTION $LASTMOD $VERSION);
    $NAME               = "amail";
    $DESCRIPTION        = "A Mail Client With A Command Line Interface";
    $LASTMOD            = 20080318;
    $VERSION            = '1.1';

    use vars            qw($DEBUG $SMTP_SERVER $DEFAULT_SENDER $DEFAULT_RECIPIENT $DEFAULT_SUBJECT $DEFAULT_BODY @FILES);
    $DEBUG              = 0;
    $SMTP_SERVER        = 'smtp.example.org';
    $DEFAULT_SENDER     = undef;
    $DEFAULT_RECIPIENT  = undef;
    $DEFAULT_SUBJECT    = undef;
    $DEFAULT_BODY       = undef;
}

my (%o, $msg);

#
# f From:
# t To:
# s Subject:
# b "body text" or "-" for <STDIN>
#
getopts('hymcd:f:t:s:b:r:', \%o);
$o{f} ||= $DEFAULT_SENDER;
$o{t} ||= $DEFAULT_RECIPIENT;
$o{s} ||= $DEFAULT_SUBJECT;
$o{b} ||= $DEFAULT_BODY;

if (@ARGV >= 1) {
    foreach my $file (@ARGV) {  # no sort performed
        push (@FILES,$file);
    }
}

if ($o{h}
    || ((!exists $o{m}) && (!exists $o{c}))
    || (exists $o{m} && (!defined $o{f} || !defined $o{t} || !defined $o{s}))
    || (exists $o{c} && !defined $o{d})) {
    die <<"    HELP_EOF"

    $NAME - $DESCRIPTION
    usage: $0 [-h] [-m] [opts] [-c] [opts]
    usage: $0 [-m] [-f from\@domain] [-t to\@domain]
        [-s "subject text"] [-b "body text" or "-"]
        [-c] [-d "user\@host:/path/to/dest" or "/local/path/dest"]
        [-r "dirpath:filename-regex:filtername"]
        [file [file]]

        -h                # This help test
        -y                # test what would happen in retrieving attachments
        [ mail features ]
        -m                # turn on the mail functionality
        -f 'u\@d.com'      # The 'From:' e-mail to be sent from
        -t 'u\@d.com'      # The 'To:' e-mail address to send to
        -s "text msg"     # The 'Subject:' text
        -b "text" or -    # The text of the body, or '-' to use <STDIN> standard input
        [ copy features ]
        -c                # turn on the copy functionality
        -d 'u\@h:/dest/'   # either a local or ssh destination directory to copy files to
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
              Linux\$ $0 -f you\@dom.com -t friend\@dom.com -s "Hello friend" \\
                -b "This is an e-mail message for my friend" \\
                photo/pictureOfMe.jpg

              # pipe text into an e-mail message
              Linux\$ cat /var/log/messages | tail -100 | $0 -f me\@dom.com \\
                -s "last 100 lines of messages log on thissys server" \\
                -t logadmin\@thissys.dom.com -b -

              Linux\$ $0 -f logadmin\@thissys.dom.com -t me\@dom.com \\
                -s "Attached are gziped logfiles smaller than 5000 bytes"
                -r '/var/logs:server\\-message\\.log\\-\\d{7,9}\\.gz:stat;size=-5000'

    Note: Copy [-c] is performed before and instead of mailing [-m]
    HELP_EOF
}

# sshexe
#
# @param  connect => 'user@host'      the user@host to connect to in the ssh session
# @param  command => 'shell command'  the shell command to execute via ssh
# @return  @output  the output of executing command
sub sshexe (%) {
    my %args    = @_;
    my $pid = sshopen3( $args{'connect'}, *READER, *WRITER, *ERROR, $args{'command'} );
    waitpid $pid, 0;
    my @out = <READER>;
    if ( $? >> 8 ) {
        while(<ERROR>) {
            push(@out,$_);
        }
    }
    close(READER);
    close(WRITER);
    close(ERROR);
    return @out;
}

# scpexe
#
# @param  source  => 'user@host:sourcefile'  the source file to copy from
# @param  target  => 'user@host:targetfile'  the target file to copy source to
# @return  $ret  a 1 for success or 0 foreach error
sub scpexe (%) {
    my %args    = @_;

    if (($args{'source'} !~ /\w/) && ($args{'target'} !~ /\w/)) {
        return 0;
    }

    my $scp = new Net::SCP( host => $args{'host'}, user => $args{'user'} );
    unless ($scp->scp($args{'source'},$args{'target'})) {
        warn $scp->{errstr};  # should maybe be terminal death, not a warning
        return 0;
    }

    return 1;
}


sub getAttachments ($) {
    my $logfilter		= shift;  # is '/path/to/file:filename-regex;filter-name:filter-options
    # $logdir     the directory to find the file
    # $fileregex  the perl-regex filename, to match and select files found in $logdir
    # $filter     the string "filter-name:filter-options" to use for filter routines below
    my ($logdir,$fileregex,$filter);
    ($logdir,$fileregex)	= split(/\:/,$logfilter,2);
    if ($fileregex =~ /([^\;]*)\;(.*)/) {
        $fileregex = $1;
        $filter    = $2;
    } else {
        $filter    = undef;
    }

    if ($fileregex eq "") {
        warn "No filename-regex was provided to option -r.\n";
        warn ("-r = ".$logdir.",".$fileregex.",".$filter."\n");
        return ();  # return empty array
    }

    # known filters:
    my $filters;
    # validates a file that matches without computing actual filters
    # like: backupfile-mail-smtp.log-20080228.gz =~ /backupfile-mail-{anyalphanumeric}.log-{latestdate}.gz/
    # should match as: backupfile-mail-smtp.log-20080228.gz =~ /backupfile-mail-.*\.log-\d{8}\.gz/
    # and thus your logfilter would be "/path/to/dir:backupfile-mail-.*\.log-\d{8}\.gz;filter-name:filter-options"
    #
    # These parameters are common for all filters, whether actually used by the filter or not
    # @param  $filter_options   the option string for this filter, passed in from logfilter
    # @param  $dir              the directory the files are found in
    # @param  @files            an array of files to search for matching regex patterns
    # @return  @filtered        an array of files, from the @files parameter, that match the regex pattern
    $filters->{'regex'} = sub {
        my $regex       = shift;  # the regex pattern to match with filenames
        print "DEBUG filters->regex called with /$regex/\n" if $DEBUG;
        my $dir         = shift;
        my @files       = @_;
        my @filtered;

        foreach my $file (@files) {
            if ($file =~ /$regex/) {
                print " FOUND ('regex'): $file\n" if $DEBUG;
                push(@filtered,$file);
            }
        }

        return @filtered;
    };
    $filters->{'stat'} = sub {
        my $optstring   = shift;
        print "DEBUG filters->stat called with /$optstring/\n" if $DEBUG;
        my $dir         = shift;
        my @files       = @_;
        my $time        = time;
        my @filtered;

        my %options;  # expected: size | atime | mtime | ctime
        foreach my $opt (split(/\,/,$optstring)) {
            if (my ($k,$v) = split(/=/,$opt,2)) {
                $options{$k} = $v;
            } else {
                $options{$opt} = 1;
            }
        }

        if ($DEBUG) {
            print "    filter->stat()\n";
            foreach my $op (keys %options) {
                print ("    ".$op." -> ".$options{$op}."\n");
            }
            print "         time: ",$time,"\n";
        }

        foreach my $file (@files) {
            my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat("$dir/$file");
            my %stats;
            $stats{'size'}	= $size;
            $stats{'atime'}	= ($time - $atime);
            $stats{'mtime'}	= ($time - $mtime);
            $stats{'ctime'}	= ($time - $ctime);
            foreach my $op (keys %options) {
                if ($options{$op} =~ /\-(\d*)/) {
                    print (" EVAL ('stat'): ".$file." ".$op." ".$stats{$op}." <= ".$1." \n") if $DEBUG;
                    if ($stats{$op} <= $1) {
                        push(@filtered,$file);
                    }
                } elsif ($options{$op} =~ /\+(\d*)/) {
                    print (" EVAL ('stat'): ".$file." ".$op." ".$stats{$op}." >= ".$1." \n") if $DEBUG;
                    if ($stats{$op} >= $1) {
                        push(@filtered,$file);
                    }
                } elsif ($options{$op} =~ /\=?(\d*)/) {
                    print (" EVAL ('stat'): ".$file." ".$op." ".$stats{$op}." == ".$1." \n") if $DEBUG;
                    if ($stats{$op} == $1) {
                        push(@filtered,$file);
                    }
                }
            }
        }

        return @filtered;
    };


    my @found_files;

    sub wanted () {
        return if -d $File::Find::name;
        return if $File::Find::name eq '.';
        return if $File::Find::name eq '..';

        my $file = $File::Find::name;
        $file =~ s/^\.\/(.*)/$1/e;
        push( @found_files, $file );
    }

    if ($logdir =~ /\/$/) {
        $logdir =~ s/\/$//;
    }
    # We need to do some figuring if the user did not provide an absolute path
    # as the logdir to the -r option.
    # i.e.: -r "relative/path/to/dir:fileregex" instead of "/path/to/dir:fileregex"
    if ($logdir !~ /^\//) {
        # File::find requires us to provide the absolute path for file searching
        if (! -x '/bin/pwd') {
            die ("Error: You must provide a absolute path for the file directory in option -r!\nYou passed in \'".$logdir."\'.");
        }
        chomp( my $cwd = `pwd` );  # makes this script not portable to Windows unless
                                   # user always passes in an absolute logdir path to -r
        if ($logdir !~ /\w/) {
            $logdir = $cwd;  # We'll search in the current working directory
        } else {
            $logdir = ($cwd."/".$logdir);  # We'll search in a sub directory from the current working directory
        }
    }

    if ($DEBUG) {
        print "    getAttachments()\n";
        print "    logfilter: ",$logfilter,"\n";
        print "       logdir: ",$logdir,"\n";
        print "    fileregex: ",$fileregex,"\n";
        print "       filter: ",$filter,"\n";
    }

    # We should be changing to an absolute directory path, without a trailing slash
    chdir($logdir);
    find (\&wanted,".");

    my @filtered_files;

    # filters
    my ($filter_name,$filter_options);
    @filtered_files = $filters->{'regex'}->($fileregex,$logdir,@found_files);
    if (defined $filter) {
        ($filter_name,$filter_options) = split(/\:/,$filter,2);
        if (defined $filters->{$filter_name}) {
            @filtered_files = $filters->{$filter_name}->($filter_options,$logdir,@filtered_files);
        } else {
            die ("filter $filter_name not recognized\n");
        }
    }

    for ( my $i = 0; $i < @filtered_files; $i++ ) {
        $filtered_files[$i] = ($logdir."/".$filtered_files[$i]);
    }

    return @filtered_files;
}


sub file_mail (@) {
    my %args    = @_;

    MIME::Lite->send('smtp', $SMTP_SERVER, Timeout=>60);

    my $msg = new MIME::Lite(
        From    => $args{'from'},
        To      => $args{'to'},
        Subject => $args{'subject'},
        Type    => "multipart/mixed",
    );
    if ($args{'body'} eq '-') {
        $msg->attach(
            Type    => 'TEXT',
            Data    => <STDIN>
        );
    } elsif (exists $args{'body'}) {
        $msg->attach(
            Type    => 'TEXT',
            Data    => $args{'body'}
        );
    }
    if (exists $args{'files'}) {
        foreach $file (@{$args{'files'}}) {
            $msg->attach(
                'Type'      => 'application/octet-stream',
                'Encoding'  => 'base64',
                'Path'      => $file
            );
        }
    }

    if (defined $args{'dry-run'}) {
        print ("TEST: ".$msg->as_string()."\n");
    } else {
        $msg->send('smtp', $SMTP_SERVER);
    }
}

sub file_copy (%) {
    my %args    = @_;
    my @files;
    if (exists $args{'files'}) {
        foreach my $file (@{$args{'files'}}) {
            push (@files,$file);
        }
    }
    foreach my $file (@files) {
        $args{'destination'} =~ s/\/$//;  # remove any trailing slash
        my $target = ( $args{'destination'} ."/". basename($file) );
        if (defined $args{'dry-run'}) {
            print "TEST: scp $file -> $target\n";
        } else {
            scpexe(source => $file, target => $target) || warn "Secure Copy failed for $file -> $target: ",$!,"\n";
        }
    }
}


# Add regex pattern matched files to the @FILES list
if (defined $o{r}) {
    my @rfiles = getAttachments($o{r});
    foreach my $rfile (sort @rfiles) {
        printf "REGEX: $rfile\n" if defined $o{y};
        push (@FILES,$rfile);
    }
}


if (exists $o{c}) {
    my %options = (
            destination => $o{d},
            );
    if (@FILES >= 1) {
        # We are expecting the @FILES array will remain unaltered
        $options{'files'} = \@FILES;
    }
    if (defined $o{y}) {
        $options{'dry-run'} = 1;
    }
    file_copy( %options );
}

if (exists $o{m}) {
    my $mbody = $o{b};
    if (exists $o{c}) {
        $mbody .= "\n\nCOPIED FILE LIST\n";
        my $i = 0;
        foreach my $file (@FILES) {
            $file = basename($file);
            $mbody .= (++$i.") ".$file."\n");
        }
    }
    print "BODY:\n$mbody\n:BODY\n" if $DEBUG;
    my %options = (
            from        => $o{f},
            to          => $o{t},
            subject     => $o{s},
            body        => $mbody
            );
    if ((! exists $o{c}) && (@FILES >= 1)) {
        # we do not mail files if we copied them somewhere
        # We are expecting the @FILES array will remain unaltered
        $options{'files'} = \@FILES;
    }
    if (defined $o{y}) {
        $options{'dry-run'} = 1;
    }
    file_mail( %options );
}


exit 0;

__END__
