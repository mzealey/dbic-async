package DBIx::Class::ResultSetWithAsync;
use strict;
use warnings;
use base 'DBIx::Class::ResultSet';
use DBIx::Class::ResultSetAsync;

# Clone the current resultset to use a new connection for the purposes of an async query.
sub async {
    my $self = shift;
    my $schema = $self->result_source->schema;
    my $new_schema = $schema->clone;

    # Force our primary schema to have a specific driver associated and then
    # load the ::Async class for the new schema
    $schema->storage->_determine_driver;
    my $async_storage_class = ref($schema->storage) . '::Async';
    if( !$self->load_optional_class($async_storage_class) ) {
        die "Could not load async driver for your DBI - $async_storage_class";
    }
    $new_schema->storage_type($async_storage_class);

    $new_schema->connection( @{$schema->storage->connect_info} );
    my $new_source = $new_schema->source($self->result_source->source_name);

    # TODO: How to handle custom resultsets?
    $new_source->resultset_class( 'DBIx::Class::ResultSetAsync' );
    return $new_source->resultset_class->new($new_source, $self->{attrs});
}

1
