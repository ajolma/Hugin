use DBI;
use Hugin;

my $html = 0;

print "<pre>" if $html;

my $domain = 'sprinkler';

$evidence_node = shift @ARGV;

my $dbh = DBI->connect('dbi:Pg:dbname=hugin;host=localhost;port=5432', 'postgres', 'lahti');

my $sth = $dbh->prepare("SELECT node FROM nodes2domains WHERE domain='$domain'");

$sth->execute();

my $d = Hugin::Domain->new();

my @nodes;
while ( my @row = $sth->fetchrow_array ) {
    push @nodes, $row[0];
}

$sth = $dbh->prepare("SELECT category,kind,labels,\"table\" FROM nodes WHERE name=?");

my %nodes;
for my $name (@nodes) {
    $sth->execute($name);
    while ( my ($category, $kind, $labels, $table) = $sth->fetchrow_array ) {
	unless (ref($labels)) {
	    $labels = splitlist($labels);
	    $table = splitlist($table);
	}
	my $n = $d->new_node($category, $kind);
	$n->set_name($name);
	$nodes{$name}{labels} = $labels;
	$nodes{$name}{table} = $table;
	$nodes{$name}{node} = $n;
    }
}

$sth = $dbh->prepare("SELECT parent FROM node2node WHERE child=?");

for my $name (@nodes) {
    $sth->execute($name);
    while ( my ($parent) = $sth->fetchrow_array ) {
	$nodes{$name}{node}->add_parent($nodes{$parent}{node});
    }
}

for my $name (@nodes) {
    $nodes{$name}{node}->set_subtype('label');
    $nodes{$name}{node}->set_number_of_states($#{$nodes{$name}{labels}}+1);
    $nodes{$name}{node}->set_state_labels(@{$nodes{$name}{labels}});
    $nodes{$name}{node}->get_table->set_data(@{$nodes{$name}{table}});
}

print "** We observe rain:\n";
select_state($nodes, 'rain', 0);

print "\n** We observe it does not rain:\n";
select_state($nodes, 'rain', 1);

print "\n** We observe grass is wet:\n";
select_state($nodes, 'grass_wet', 0);

print "\n**We observe grass is not wet:\n";
select_state($nodes, 'grass_wet', 1);

print "\n**Evidence shows that grass is not wet with probability 0.9:\n";

$nodes{grass_wet}{node}->enter_findings(0.1, 0.9);
$d->compile;
$d->propagate('sum', 'normal');
$nodes{grass_wet}{node}->retract_findings;
dump_domain($d);

print "</pre>" if $html;

sub select_state {
    my($nodes, $node, $state) = @_;
    $nodes{$node}{node}->select_state($state);
    $d->compile;
    $d->propagate('sum', 'normal');
    $nodes{$node}{node}->retract_findings;
    dump_domain($d);
}

sub dump_domain {
    my $d = shift;
    for my $n ($d->get_nodes) {
	my $name = $n->get_name;
	my $label = $n->get_label;
	$label =~ s/\n/ /g;
	my @p = $n->get_position;
	my $cat = $n->get_category;
	my $st = $n->get_subtype;
	my @ns = $n->get_state_labels;
	my %a = $n->get_attributes;
	my $t = $n->get_table;
	my @t = $t->get_data;
	my @s = $n->get_state_values;
	my @b = $n->get_beliefs;	
	my @par = map($_->get_name, $n->get_parents);
	my @chld = map($_->get_name, $n->get_children);
	printf("Node: %9s: ", $name); # ($label) (@ns) $cat($st)\n";
	#print "\t@p (@par, @chld)\n";
	for (keys %a) {
	    #print STDERR "  $_ => $a{$_}\n";
	}
	#print STDERR "  @t\n";
	#print STDERR "  @s\n";
	printf("  P(T) = %.3f P(F) = %.3f\n",@b);
    }
}

sub splitlist {
    my $l = shift;
    $l =~ s/^\{//;
    $l =~ s/\}$//;
    my @l = split /,/, $l;
    return \@l;
}
