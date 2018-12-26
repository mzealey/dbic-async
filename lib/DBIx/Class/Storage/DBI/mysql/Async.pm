package DBIx::Class::Storage::DBI::mysql::Async;

use strict;
use warnings;
use base 'DBIx::Class::Storage::DBI::mysql';
use mro 'c3';
use DBIx::Class::Storage::DBI::mysql::Async::Request;

__PACKAGE__->cursor_class('DBIx::Class::Storage::DBI::Cursor::Async');

# Change DBIx::Class::Storage::DBI::select_single to return a promise async

# This called by everything basically
sub _prepare_sth {
  my ($self, $dbh, $sql) = @_;

  # 3 is the if_active parameter which avoids active sth re-use
  my $sth = $self->disable_sth_caching
    ? $dbh->prepare($sql, { async => 1 })
    : $dbh->prepare_cached($sql, { async => 1 }, 3);

  # XXX You would think RaiseError would make this impossible,
  #  but apparently that's not true :(
  $self->throw_exception(
    $dbh->errstr
      ||
    sprintf( "\$dbh->prepare() of '%s' through %s failed *silently* without "
            .'an exception and/or setting $dbh->errstr',
      length ($sql) > 20
        ? substr($sql, 0, 20) . '...'
        : $sql
      ,
      'DBD::' . $dbh->{Driver}{Name},
    )
  ) if !$sth;

    # TODO: Find a nice way to pass 2nd argument for timeout
    return DBIx::Class::Storage::DBI::mysql::Async::Request->new( $sth ); #, 0.01 );
}

# ResultSet update/delete should work fine returning just a promise

1
