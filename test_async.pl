#!/usr/bin/perl
use v5.16;
use Promises backend => ['EV'], warn_on_unhandled_reject => [1];
use FindBin::libs;
use strictures;
use Try::Tiny;

use AnyEvent::Impl::EV;
use EV;
use Data::Printer;

use Songs::AsyncSchema;

my $dbic = Songs::AsyncSchema->connect();
my $rs = $dbic->resultset('Song');

test_crud();
test_count();
test_cancel();

sub test_crud {
    $rs->search({ id => 2 })->async
        ->update_p({ song_ts_epoch => int(rand() * time) })
        ->then(sub {
            my ($rv) = @_;
            say "Update completed. Return value: $rv";
        });

    #$dbic->resultset('Tag')->async->create({
    #        tag_code => rand() * time,
    #        tag_group => 'test',
    #    })->then(sub {
    #        my ($rv) = @_;
    #        say "Insert completed. Return: $rv";
    #    });

    $rs->search({ id => 100_000 })->async
        ->delete_p
        ->then(sub {
            my ($rv) = @_;
            say "Delete completed. Return $rv";
        });
    EV::run;
}

sub test_count {
    $rs->async->count_p->then(sub {
        my ($count) = @_;
        say "Count: $count";
    });
    $rs->search({}, { rows => 2 })->async->all_p->then(sub {
        p @_;
    });
    EV::run;
}

sub test_cancel {
    my @promises;
    my $rs = $dbic
            ->resultset('Song')
            ->search({
            }, {
                columns => [
                    { foo => \'sum(length(songxml))' }
                ],
            });

    for my $id (1..3) {
        my $promise = $rs->async->all_p;
        push @promises, $promise;

        $promise
            ->then(sub {
                my (@rows) = @_;
                warn "$id done";
                #$_->cancel for @promises;
                for my $row (@rows) {
                    p $row;
                }
            }, sub {
                warn "Error $id: " . shift;
            });
    }

    my $promise = $dbic
        ->resultset('Song')
        ->search({}, { rows => 1 })
        ->async
        ->all_p
        ->then(sub {
            warn 'cancel';
            for( @promises) {
                try {
                    $_->cancel
                } catch {
                    say $_
                };
            }
        });

    warn 'running';
    EV::run;
}
