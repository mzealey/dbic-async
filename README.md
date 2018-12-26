Attempt at some modules to add Async functionality to DBIx::Class

Set up a Schema object similar to your existing one, but using a few custom parameters::

    use utf8;
    package Songs::AsyncSchema;

    use strict;
    use warnings;

    use Songs::Schema;      # current schema
    use base 'DBIx::Class::Schema';

    # If it was not for the default_resultset_class needing to be set then we could do this as a separate connect_async function in Songs::Schema
    __PACKAGE__->load_namespaces(
        result_namespace => '+Songs::Schema::Result',       # use current schema
        default_resultset_class => '+DBIx::Class::ResultSetAsync'
    );

    # Set to the database driver you use
    __PACKAGE__->storage_type('::DBI::Pg::Async');
    #__PACKAGE__->storage_type('::DBI::mysql::Async');

    sub connect {
        my $self = shift;
        # If no need for default_resultset_class setting above we could set the async here directly at instantiation
        #$self->storage_type('::DBI::Pg::Async');       
        $self->SUPER::connect( @{Songs::Schema->conn_info} );
    }

    1;
