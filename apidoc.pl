# perl apidoc.pl < Hugin.xs >temp.pm; doxygen; rm temp.pm
# doxygen needs tweaked PerlFilter

my $on = 0;
while (<STDIN>) {
    if (/^=pod/) {
	$on = 1;
	next;
    }
    $on = 0 if /^=cut/;
    next unless $on;
    print "#" if /^\@class/ or /^\@cmethod/ or /^\@method/ or /^\@attr/ or /^\@ignore/;
    print "# " unless /^\s*$/;
    print;
}
