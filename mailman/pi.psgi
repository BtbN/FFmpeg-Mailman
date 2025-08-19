use PublicInbox::WWW;
my $www = PublicInbox::WWW->new;
builder {
	enable 'Head';
	enable 'ReverseProxy';
	mount '@@@MOUNTPOINT@@@' => sub { $www->call(@_) };
};
