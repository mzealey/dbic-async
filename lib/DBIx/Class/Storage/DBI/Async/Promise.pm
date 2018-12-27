package DBIx::Class::Storage::DBI::Async::Promise;
use strict;
use warnings;
use base 'Promises::Promise';

sub cancel { (shift)->{'deferred'}->cancel }

1
