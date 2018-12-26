package DBIx::Class::Storage::DBI::Pg::Async::Request;
use strict;
use warnings;
use base 'DBIx::Class::Storage::DBI::Async::Request';

sub _fh_to_watch {
    # If we need a file handle for any reason, otherwise this is just a file descriptor
    #open my $sock, '<&', $shift->dbh->{pg_socket} or die "Can't dup: $!";
    return shift->dbh->{pg_socket};
}

sub _query_completed { shift->dbh->pg_ready }
sub _get_execute_result { shift->dbh->pg_result }
sub _cancel_query { shift->sth->pg_cancel }

1;
