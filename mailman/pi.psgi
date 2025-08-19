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
	mount '@@@MOUNTPOINT@@@' => sub {
		$_[0]->{PATH_INFO} ||= '/';
		return $www->call(@_);
	};
};
