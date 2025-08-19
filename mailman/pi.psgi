#!/usr/bin/perl -w
use strict;
use warnings;
use Plack::Builder;
use PublicInbox::WWW;

my $www = PublicInbox::WWW->new;
$www->preload;

builder {
	enable 'ReverseProxy';
	enable 'Head';
	mount '@@@MOUNTPOINT@@@' => sub { $www->call(@_) };
};
