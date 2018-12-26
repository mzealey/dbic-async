package DBIx::Class::Storage::DBI::mysql::Async::Request;
use strict;
use warnings;
use base 'DBIx::Class::Storage::DBI::Async::Request';

sub _fh_to_watch { shift->dbh->mysql_fd }

sub _query_completed { shift->sth->mysql_async_ready }
sub _get_execute_result { shift->sth->mysql_async_result }

1
