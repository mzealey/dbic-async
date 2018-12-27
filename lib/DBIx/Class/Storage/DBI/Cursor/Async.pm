package DBIx::Class::Storage::DBI::Cursor::Async;
use strict;
use warnings;
use base 'DBIx::Class::Storage::DBI::Cursor';
use mro 'c3';
use List::Util 'shuffle';

# Custom cursor which returns promises for Async requests rather than result sets

# Call this first, wait for the response and then call ->all to fetch the rows
sub all_p {
  my $self = shift;

  ## delegate to DBIC::Cursor which will delegate back to next()
  #if ($self->{attrs}{software_limit}
  #      && ($self->{attrs}{offset} || $self->{attrs}{rows})) {
  #  return $self->next::method(@_);
  #}

  my $sth;

  #if ($sth = $self->sth) {
  #  # explicit finish will issue warnings, unlike the DESTROY below
  #  $sth->finish if ( ! $self->{_done} and $sth->FETCH('Active') );
  #  $self->sth(undef);
  #}

  (undef, $sth) = $self->storage->_select( @{$self->{args}} );
  $self->{_cur_sth} = $sth;

  return $sth;
}

# Fake ->all if ->all_p was completed
sub all {
    my $self = shift;

    my $sth = $self->{_cur_sth};
    warn 'return';
      return(
        DBIx::Class::_ENV_::SHUFFLE_UNORDERED_RESULTSETS
          and
        ! $self->{attrs}{order_by}
      )
        ? shuffle @{$sth->fetchall_arrayref}
        : @{$sth->fetchall_arrayref};
}

sub next_p {
  my $self = shift;

  my $sth;

  if ($sth = $self->sth) {
    # explicit finish will issue warnings, unlike the DESTROY below
    $sth->finish if $sth->FETCH('Active');
  }

  (undef, $sth, undef) = $self->storage->_select( @{$self->{args}} );
  return $sth->then(sub {
    my ($sth) = @_;
    $self->sth($sth);

    $self->{_results} = [ (undef) x $sth->FETCH('NUM_OF_FIELDS') ];
    $sth->bind_columns( \( @{$self->{_results}} ) );

    if ( $self->{attrs}{software_limit} and $self->{attrs}{offset} ) {
      $sth->fetch for 1 .. $self->{attrs}{offset};
    }
  });
}

1;
