# perl apidoc.pl < Hugin.xs >temp.pm; doxygen; rm temp.pm

my $on = 0;
my $class;
my $method_name;
while (<STDIN>) {
    if (/^=pod/) {
        $on = 1;
        next;
    }
    if (/^=cut/) {
        print "#*\n";
        $on = 0;
        if ($class) {
            print "package $class;\n\n";
            $class = '';
        } elsif ($method_name) {
            print "sub $method_name {\n}\n\n";
        }
    }
    next unless $on;
    
    #print STDERR unless /^\s*$/;
    #next;

    if (/^\@class/ or /^\@cmethod/ or /^\@method/) {
        s/^\@cmethod/\@method/;
        s/^\@method/\@function/;
        print "#** $_";
    } else {
        print "# $_" unless /^\s*$/;
    }
    
    chomp;
    if (/^\@class/) {
        $class = $_;
        $class =~ s/\@\w+\s+//;
        #print STDERR "'$_': $class\n" if $class;
    } elsif (/^\@cmethod/ or /^\@method/ or /^\@function/) {
        $method_name = $_;
        $method_name =~ s/\@\w+\s+//;
        my ($retval) = $method_name =~ /^(\S+)/;
        $method_name =~ s/^$retval\s+// if !($retval =~ /\(/);
        $method_name =~ s/\(.*//;
        $method_name =~ s/^[\$\@]//;
        #print STDERR "'$_': $method_name\n" if $method_name;
    }
}
