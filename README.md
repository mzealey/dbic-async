Attempt at some modules to add Async functionality to DBIx::Class

Set up a Schema object similar to your existing one, but using a custom resultset which contains the `->async` command::

    use utf8;
    package Songs::AsyncSchema;

    use strict;
    use warnings;

    use Songs::Schema;      # current schema
    use base 'DBIx::Class::Schema';

    # If it was not for the default_resultset_class needing to be set then we could do this as a separate connect_async function in Songs::Schema
    __PACKAGE__->load_namespaces(
        result_namespace => '+Songs::Schema::Result',       # use current schema
        default_resultset_class => '+DBIx::Class::ResultSetWithAsync'
    );

    1;

Once you have a resultset that you want to run async, call it like::

    $rs->async->all_p->then(sub {
        my (@rows) = @_;
    });

Remember you can only have one active command live on each async connection so
you probably want to do a number of queries like the above and then run the
event runner on them.
