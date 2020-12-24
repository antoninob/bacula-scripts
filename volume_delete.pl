#!/usr/bin/perl
use strict;
use Getopt::Long;
use IPC::Open2;
use IO::Handle;


my $bconsole = '/usr/sbin/bconsole';
my (%opts, @purged, $pid);

GetOptions(\%opts,
           'verbose|v',
           'test');

my ($IN, $OUT) = (IO::Handle->new(), IO::Handle->new());

$pid = open2($OUT, $IN, $bconsole) || die "Unable to open bconsole";

if (scalar (@purged = check_volumes()))
{
    printf("Bacula reports the following purged volumes:\n\t%s\n",
           join("\n\t", @purged)) if ($opts{verbose});
    my $deleted = delete_volumes(@purged);
    print "$deleted volumes deleted.\n" if ($opts{verbose});
}
elsif ($opts{verbose})
{
    print "No purged volumes found to delete.\n";
}

print $IN "exit\n";
waitpid($pid, 0);

exit (0);


sub check_volumes
{
    my $dividers = 0;
    my (@purged, @row);

    print $IN "list volumes pool=Scratch\n";
    for (;;)
    {
        my $resp = <$OUT>;
        last if ($resp =~ /No results to list./);
        $dividers++ if ($resp =~ /^[\+\-]+$/);
        last if ($dividers == 3);
        @row = split(/\s+/, $resp);
        push (@purged, $row[3]) if ($row[5] eq 'Purged');
    }

    return (@purged);
}


sub delete_volumes
{
    my $volume_dir = '/spool/bacula/';
    my $count = 0;

    foreach my $vol (@_)
    {
        my $l;
        my $file = $volume_dir.$vol;

        print "Deleting volume $vol from catalog ... " if ($opts{verbose});
        print $IN "delete volume=$vol yes\n";
        $l = <$OUT>;
        $l = <$OUT>;
        print "Done.\nDeleting volume $file from disk ... " if ($opts{verbose});
        if (-f $file)
        {
            $count++;
            unlink ($file);
        }
        print "Done.\n" if ($opts{verbose});
    }

    return ($count);
}
