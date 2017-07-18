package Hugin;

#use 5.010000;
use strict;
use warnings;
use Carp;
use Archive::Zip;

require Exporter;
use AutoLoader;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use Hugin ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);

our $VERSION = '0.01';

sub AUTOLOAD {
    # This AUTOLOAD is used to 'autoload' constants from the constant()
    # XS function.

    my $constname;
    our $AUTOLOAD;
    ($constname = $AUTOLOAD) =~ s/.*:://;
    croak "&Hugin::constant not defined" if $constname eq 'constant';
    my ($error, $val) = constant($constname);
    if ($error) { croak $error; }
    {
	no strict 'refs';
	# Fixed between 5.005_53 and 5.005_61
#XXX	if ($] >= 5.00561) {
#XXX	    *$AUTOLOAD = sub () { $val };
#XXX	}
#XXX	else {
	    *$AUTOLOAD = sub { $val };
#XXX	}
    }
    goto &$AUTOLOAD;
}

require XSLoader;
XSLoader::load('Hugin', $VERSION);

# Preloaded methods go here.

# Autoload methods go after =cut, and are processed by the autosplit program.

sub create_db {
    my($dbh, %param) = @_;
    my @schema = (
	collections => [
	    id => 'serial PRIMARY KEY', 
	    name => 'text'
	],
	classes => [
	    id => 'serial PRIMARY KEY', 
	    name => 'text',
	    node_size => 'integer[]',
	    kind => 'text'
	],
	nodes => [
	    id => 'serial PRIMARY KEY', 
	    name => 'text',
	    iklass => 'integer REFERENCES classes(id) ON DELETE CASCADE',
	    category => 'text',
	    kind => 'text',
	    subtype => 'text',
	    interface => 'text',
	    clone_of => 'integer',
	    instance => 'integer',
	    label => 'text',
	    position => 'integer[]',
	    states => 'text[]',
	    cpt => 'double precision[]',
	    model_nodes => 'text',
	    model_data => 'text'
	],
	class2collection => [
	    id => 'serial PRIMARY KEY',
	    klass => 'integer REFERENCES classes(id)',
	    collection => 'integer REFERENCES collections(id) ON DELETE CASCADE'
	],
	node2class => [
	    id => 'serial PRIMARY KEY',
	    node => 'integer REFERENCES nodes(id)',
	    klass => 'integer REFERENCES classes(id) ON DELETE CASCADE'
	],
	node2node => [
	    id => 'serial PRIMARY KEY',
	    parent => 'integer REFERENCES nodes(id) ON DELETE CASCADE',
	    child => 'integer REFERENCES nodes(id) ON DELETE CASCADE'
	],
	class_attr => [
	    id => 'serial PRIMARY KEY',
	    klass => 'integer REFERENCES classes(id) ON DELETE CASCADE',
	    attr => 'text',
	    value => 'text'
	],
	node_attr => [
	    id => 'serial PRIMARY KEY',
	    node => 'integer REFERENCES nodes(id) ON DELETE CASCADE',
	    attr => 'text',
	    value => 'text'
	],
	inputs => [
	    id => 'serial PRIMARY KEY',
	    actual => 'integer REFERENCES nodes(id) ON DELETE CASCADE',
	    input => 'integer REFERENCES nodes(id) ON DELETE CASCADE'
	]
	);
    if ($param{drop}) {
	my $sql = 
	    'drop table if exists nodes cascade;'.
	    'drop table if exists classes cascade;'.
	    'drop table if exists collections cascade;'.
	    'drop table if exists class2collection cascade;'.
	    'drop table if exists node2class cascade;'.
	    'drop table if exists node2node cascade;'.
	    'drop table if exists class_attr cascade;'.
	    'drop table if exists node_attr cascade;'.
	    'drop table if exists inputs cascade;';
	$dbh->do($sql) or croak($dbh->errstr);
    }
    for (my $i = 0; $i < @schema; $i+=2) {
	my $table = $schema[$i+1];
	my @cols;
	for (my $j = 0; $j < @$table; $j+=2) {
	    push @cols, "\"$table->[$j]\" $table->[$j+1]";
	}
	my $sql = 'CREATE TABLE '.$schema[$i].'('.join(',',@cols).");\n";
	$dbh->do($sql) or croak($dbh->errstr);
    }
}

sub empty_db {
    my($dbh, %param) = @_;
    my $sql = 
	'delete from collections;'.
	'delete from classes;'.
	'delete from nodes;';
    $dbh->do($sql) or croak($dbh->errstr);
}

package Hugin::Collection;
use Carp;

sub new_from_zip_file {
    my($package, $filename, $tmpdir) = @_;
    $tmpdir .= '/' unless $tmpdir =~ /\/$/; # hugin oddity
    my $zip = Archive::Zip->new();
    my $error = $zip->read($filename);
    croak("Error in zip file: $error") if $error;
    my @oobn;
    for ($zip->memberNames()) {
	push @oobn, $_ if /oobn$/;
    }
    chdir($tmpdir);
    my %ref;
    my %models;
    for my $member (@oobn) {
	$zip->extractMemberWithoutPaths($member);
	my($volume,$path,$file) = File::Spec->splitpath($member);
	my($model, $ext) = split /\./, $file;
	my $fh;
	open($fh, $file);
	while (<$fh>) {
	    if (/^\s*instance\s+\w+\s+:\s+(\w+)/) {
		$ref{$model}{$1} = 1;
		$models{$model} = 1;
	    }
	}
	close $fh;
    }
    for my $m (sort keys %ref) {
	for (sort keys %{$ref{$m}}) {
	    delete $models{$_};
	}
    }
    my @model = sort keys %models;
    my $collection = $package->new();
    $collection->parse($tmpdir, $model[0]);
    for (@oobn) {
	#unlink($_);
    }
    return $collection;
}

sub to_db {
    my($collection, $dbh, $name) = @_;
    if (defined $name) {
	$dbh->do("insert into collections (name) values ('$name')") or croak($dbh->errstr);
    }
    my %class_id;
    my %id;
    for my $class ($collection->get_classes()) {
	my($id, $nodes) = $class->to_db($dbh);
	$class_id{$class->get_name} = $id;
	$id{$class->get_name} = $nodes;
	next unless defined $name;
	$dbh->do("insert into class2collection (klass,collection) values ".
		 "($id, currval('collections_id_seq'))") or croak($dbh->errstr);
    }
    # links into instantiated classes
    for my $class ($collection->get_classes()) {
	my $name = $class->get_name;
	for my $inode ($class->get_nodes) {
	    next unless $inode->get_category eq 'instance';
	    my $id = $id{$name}{$inode->get_name};
	    my $iclass = $inode->get_instance_class;
	    my $iname = $iclass->get_name;
	    $dbh->do("update nodes set iklass=$class_id{$iname} where id=$id") or croak($dbh->errstr);
	    for my $node ($iclass->get_inputs) {
		my $actual = $inode->get_input($node);
		my $parent = $id{$name}{$actual->get_name};

		$dbh->do("insert into node2node (parent,child) values ($parent,$id)") or croak($dbh->errstr);

		my $iid = $id{$iname}{$node->get_name};
		$dbh->do("insert into inputs (actual,input) values ($parent,$iid)") or croak($dbh->errstr);

	    }
	}
    }
    # output clones
    for my $class ($collection->get_classes()) {
	for my $inode ($class->get_nodes) {
	    next unless $inode->get_category eq 'instance';
	    my $iclass = $inode->get_instance_class;
	    for my $node ($iclass->get_outputs) {
		my $clone = $inode->get_output($node);		
		my $clone_of = $id{$iclass->get_name}{$node->get_name};
		my $id = $id{$class->get_name}{$clone->get_name};
		my $i = $id{$class->get_name}{$inode->get_name};
		$dbh->do("update nodes set clone_of=$clone_of,instance=$i where id=$id") or croak($dbh->errstr);
	    }
	}
    }
}

sub new_from_db {
    my($package, $dbh, $name) = @_;
    my $collection = $package->new();
    my $sth = $dbh->prepare("select id from collections where name='$name'") or croak($dbh->errstr);
    my $rv = $sth->execute or croak($dbh->errstr);
    croak "no such collection: '$name'" unless $sth->rows;
    my($id) = $sth->fetchrow_array;

    # create classes with nodes
    my($classes, $nodes) = $collection->create_classes($dbh, $id);
    my @classes = keys %$classes;

    # create instances
    my $instances = $collection->create_instances($dbh, $classes, $nodes);

    # specify inputs to submodel
    $collection->specify_links($dbh, \@classes, $instances, $nodes);    

    return $collection;
}

sub new_from_db_with_id {
    my($package, $dbh, $id) = @_;
    my $collection = $package->new();

    # create classes with nodes
    my($classes, $nodes) = $collection->create_classes($dbh, $id);
    my @classes = keys %$classes;

    # create instances
    my $instances = $collection->create_instances($dbh, $classes, $nodes);

    # specify inputs to submodel
    $collection->specify_links($dbh, \@classes, $instances, $nodes);    

    return $collection;
}

sub new_from_db_with_class_id {
    my($package, $dbh, $id) = @_;
    my $collection = $package->new();

    my @is_instantiated_in = Hugin::Class::is_instantiated_in($dbh);
    my @classes = ($id);
    push @classes, Hugin::Class::instantiated_in($id, \@is_instantiated_in);

    # create classes with nodes
    my %classes;
    my %nodes;
    for my $id (@classes) {
	my $class = $collection->new_class;
	$class->from_db($dbh, $id, \%nodes);
	$classes{$id} = $class;
    }

    # create instances
    my $instances = $collection->create_instances($dbh, \%classes, \%nodes);

    # specify inputs to submodel
    $collection->specify_links($dbh, \@classes, $instances, \%nodes);

    return $collection;
}

sub create_classes {
    my($self, $dbh, $id) = @_;
    #print STDERR "create classes $id\n";
    my $sth = $dbh->prepare("select klass from class2collection where collection=$id") 
	or croak($dbh->errstr);
    my $rv = $sth->execute or croak($dbh->errstr);
    my %classes;
    my %nodes;
    for (1..$sth->rows) {
	($id) = $sth->fetchrow_array;
	my $class = $self->new_class;
	$class->from_db($dbh, $id, \%nodes);
	$classes{$id} = $class;
    }
    return (\%classes, \%nodes);
}

sub create_instances {
    my($self, $dbh, $classes, $nodes) = @_;
    my @classes = keys %$classes;
    #print STDERR "create instances @classes\n";
    my $sql = "select nodes.id,node2class.klass,nodes.iklass,nodes.name,nodes.position,nodes.label ".
	"from nodes,node2class ".
	"where node2class.node=nodes.id and category='instance' ".
	"and node2class.klass=?";
    my $sth = $dbh->prepare($sql) or croak($dbh->errstr);
    my %instances;
    for my $id (@classes) {
	my $rv = $sth->execute($id) or croak($dbh->errstr);
	for (1..$sth->rows) {
	    my($id,$klass,$iklass,$name,$position,$label) = Hugin::row($sth);
	    my $node = $classes->{$klass}->new_instance($classes->{$iklass});
	    $instances{$klass}{$iklass} = $id;
	    $nodes->{$id}{node} = $node;
	    $node->set_name($name);
	    $node->set_label($label);
	    $node->set_position($position->[0], $position->[1]) if ($position and @$position);
	}
    }
    return \%instances;
}

sub specify_links {
    my($self, $dbh, $classes, $instances, $nodes) = @_;
    #print STDERR "specify links\n";

    # specify inputs

    my $sth = $dbh->prepare("select actual,\"input\" from inputs,node2class ".
			    "where node2class.node=inputs.actual and node2class.klass=?")
	or croak($dbh->errstr);
    for my $id (@$classes) {
	my $rv = $sth->execute($id) or croak($dbh->errstr);
	for (1..$sth->rows) {
	    my($actual, $input) = $sth->fetchrow_array;
	    next unless $nodes->{$actual} and $nodes->{$input};
	    my $instance = $instances->{$nodes->{$actual}{class}}{$nodes->{$input}{class}};
	    #print STDERR "$instance->set_input($input, $actual)\n";
	    $nodes->{$instance}{node}->set_input($nodes->{$input}{node}, $nodes->{$actual}{node});
	}
    }
    
    # specify clones as parents
    # clones have been created by Hugin

    my @children;
    $sth = $dbh->prepare("select child,clone_of,instance ".
			 "from node2node,nodes,node2class ".
			 "where node2node.parent=nodes.id and clone_of is not null ".
			 "and node2class.node=nodes.id and node2class.klass=?")
	or croak($dbh->errstr);
    for my $id (@$classes) {
	my $rv = $sth->execute($id) or croak($dbh->errstr);
	for (1..$sth->rows) {
	    my($child, $clone_of, $instance) = $sth->fetchrow_array;
	    my $clone = $nodes->{$instance}{node}->get_output($nodes->{$clone_of}{node});
	    #print STDERR "$instance->get_output($clone_of) is $clone, set as parent to $child\n";
	    $nodes->{$child}{node}->add_parent($clone);	    
	    push @children, $child;
	}
    }

    # CPTs of the children of clones must wait until here

    $sth = $dbh->prepare("select cpt from nodes where id=?")
	or croak($dbh->errstr);
    for my $id (@children) {
	my $rv = $sth->execute($id) or croak($dbh->errstr);
	for (1..$sth->rows) {
	    my($cpt) = Hugin::row($sth);
	    $nodes->{$id}{node}->get_table->set_data(@$cpt);
	    my @cpt = $nodes->{$id}{node}->get_table->get_data();
	}
    }
    
}

sub delete_from_db {
    my($package, $dbh, $id) = @_;
    my $sql = 
	"delete from collections where id='$id';\n". # deletes rows from class2collection
	"delete from classes where id not in\n".
	"(select klass from class2collection) and kind is null;\n". # deletes rows from class_attr and node2class
	"delete from nodes where id not in\n".
	"(select node from node2class);\n"; # deletes rows from node2node and node_attr
    $dbh->do($sql) or croak($dbh->errstr);
}

package Hugin::Class;
use Carp;

sub to_db {
    my($self, $dbh) = @_;
    my @node_size = $self->get_node_size;
    my $name = $self->get_name;
    $dbh->do("insert into classes (name,node_size) values ".
	     "('$name','{$node_size[0],$node_size[1]}')") or croak($dbh->errstr);
    my $sth = $dbh->prepare("select currval('classes_id_seq')") or croak($dbh->errstr);
    $sth->execute or croak($dbh->errstr);
    my($id) = $sth->fetchrow_array;
    my %attr = $self->get_attributes;
    for my $key (keys %attr) {
	my $val = $attr{$key};
	$val =~ s/\n/\\n/g;
	$val =~ s/'/\\'/g;
	$dbh->do("insert into class_attr (klass,attr,value) values ".
		 "($id, '$key', E'$val')") or croak($dbh->errstr);
    }
    my %nodes;
    for my $node ($self->get_nodes) {
	my $nid = $node->to_db($dbh);
	$nodes{$node->get_name} = $nid;
	$dbh->do("insert into node2class (node,klass) values ".
		 "($nid, $id)") or croak($dbh->errstr);
    }
    for my $node ($self->get_inputs) {
	$dbh->do("update nodes set interface='input' where id=$nodes{$node->get_name}") or croak($dbh->errstr);
    }
    for my $node ($self->get_outputs) {
	$dbh->do("update nodes set interface='output' where id=$nodes{$node->get_name}") or croak($dbh->errstr);
    }
    for my $node ($self->get_nodes) {
	if ($node->get_category eq 'instance') {
	    
	} else {
	    for my $parent ($node->get_parents()) {
		my $id = $nodes{$node->get_name};
		my $parent_id = $nodes{$parent->get_name};
		$dbh->do("insert into node2node (parent,child) values ($parent_id,$id)") or croak($dbh->errstr);
	    }
	}
    }
    return ($id, \%nodes);
}

sub from_db {
    my($self, $dbh, $id, $nodes) = @_;
    #print STDERR "create class $id\n";

    # set name and node size

    my $sth = $dbh->prepare("select name,node_size from classes where id='$id'") or croak($dbh->errstr);
    my $rv = $sth->execute or croak($dbh->errstr);
    croak "no such class: '$id'" unless $sth->rows;
    my($name, $node_size) = Hugin::row($sth);
    $self->set_name($name);
    $self->set_node_size($node_size->[0], $node_size->[1]) if defined $node_size->[0];

    # set attributes

    $sth = $dbh->prepare("select attr,value from class_attr where klass='$id'") or croak($dbh->errstr);
    $rv = $sth->execute or croak($dbh->errstr);
    for (1..$sth->rows) {
	my($attr, $value) = Hugin::row($sth);
	$self->set_attribute($attr, $value);
    }

    # create nodes, but not instance nodes and clones
    
    $sth = $dbh->prepare("select nodes.id,name,category,kind,subtype,label,position,states,cpt,model_nodes,model_data ".
			 "from node2class,nodes ".
			 "where node2class.klass='$id' and node2class.node=nodes.id and ".
			 "clone_of is null and category!='instance'") 
	or croak($dbh->errstr);
    $rv = $sth->execute or croak($dbh->errstr);
    my %nodes; # of this class, $nodes references nodes of all classes within a collection
    my %cpt;
    my %models;
    my %nodes_by_name;
    for (1..$sth->rows) {
	my($node_id,$name,$category,$kind,$subtype,$label,$position,$states,$cpt,$model_nodes,$model_data) = Hugin::row($sth);
	$position = [0,0] unless $position;
	#print STDERR "create node $node_id,$name,$category,$kind,$subtype,$label\n";

	my $node = $self->new_node($category, $kind);

	$nodes{$node_id} = $node;
	$nodes_by_name{$name} = $node;
	$nodes->{$node_id}{node} = $node;
	$nodes->{$node_id}{class} = $id;

	$node->set_name($name);
	$node->set_label($label);
	$node->set_position($position->[0], $position->[1]);
	my $n = scalar(@$states);
	$node->set_number_of_states($n) if $n > 0 and $category ne 'utility';
	$node->set_subtype($subtype) unless ($category eq 'utility' or $subtype eq 'error');
	if ($subtype eq 'interval') {
	    my @s;
	    for (@$states) {
		s/^\[//;
		s/\)$//;
		my @a = split /,/;
		push @s, $a[0];
	    }
	    $node->set_state_values(@s);
	} if ($subtype eq 'number') {
	    $node->set_state_values(@$states);
	} else {
	    $node->set_state_labels(@$states);
	}
	$cpt{$node_id} = $cpt;
	$models{$node_id}{nodes} = $model_nodes if $model_nodes;
	$models{$node_id}{data} = $model_data if $model_data;
    }

    # set attributes

    $sth = $dbh->prepare("select attr,value from node_attr where node=?") or croak($dbh->errstr);
    for my $node (keys %nodes) {
	$sth->execute($node) or croak($dbh->errstr);
	for (1..$sth->rows) {
	    my($attr, $value) = Hugin::row($sth);
	    $nodes{$node}->set_attribute($attr, $value);
	}
    }

    # set inputs and outputs   

    $sth = $dbh->prepare("select nodes.id ".
			 "from node2class,nodes ".
			 "where node2class.klass='$id' and node2class.node=nodes.id ".
			 "and nodes.id in (select input from inputs)") 
	or croak($dbh->errstr);
    $rv = $sth->execute or croak($dbh->errstr);
    for (1..$sth->rows) {
	my($node) = $sth->fetchrow_array;
	$nodes{$node}->add_to_inputs;
    }

    $sth = $dbh->prepare("select n.id ".
			 "from node2class,nodes as n, nodes as p ".
			 "where node2class.klass='$id' and node2class.node=n.id ".
			 "and p.clone_of=n.id") 
	or croak($dbh->errstr);
    $rv = $sth->execute or croak($dbh->errstr);
    for (1..$sth->rows) {
	my($node) = $sth->fetchrow_array;
	$nodes{$node}->add_to_outputs;
    }

    $sth = $dbh->prepare("select nodes.id,interface ".
			 "from node2class,nodes ".
			 "where node2class.klass='$id' and node2class.node=nodes.id") 
	or croak($dbh->errstr);
    $rv = $sth->execute or croak($dbh->errstr);
    for (1..$sth->rows) {
	my($node, $interface) = $sth->fetchrow_array;
	next unless $interface;
	if ($interface eq 'input') {
	    #$nodes{$node}->add_to_inputs;
	} elsif ($interface eq 'output') {
	    #$nodes{$node}->add_to_outputs;
	}
    }

    # add parents
    # order by id is important since the order of parents is important!

    $sth = $dbh->prepare("select parent from node2node,nodes ".
			 "where parent=nodes.id and nodes.clone_of is null and child=? ".
			 "order by node2node.id desc") or croak($dbh->errstr);
    for my $node (keys %nodes) {
	next if $nodes{$node}->get_category eq 'instance';
	$sth->execute($node) or croak($dbh->errstr);
	for (1..$sth->rows) {
	    my($parent) = $sth->fetchrow_array;
	    $nodes{$node}->add_parent($nodes{$parent});
	}
    }

    # set tables, but see set_links above

    for my $node (keys %nodes) {
	next if $models{$node};
	$nodes{$node}->get_table->set_data(@{$cpt{$node}});
    }

    # set models

    for my $node (keys %nodes) {
	next unless $models{$node};
	my @nodes = split /,/, $models{$node}{nodes} if $models{$node}{nodes};
	for (@nodes) {
	    croak "model node does not exist: $_" unless $nodes_by_name{$_};
	    $_ = $nodes_by_name{$_};	    
	}
	my $model = $nodes{$node}->new_model(@nodes);
	my @data = split /,/, $models{$node}{data};
	for my $i (0..@data-1) {
	    my $e = $model->expression_from_string($data[$i]);
	    $model->set_expression($i, $e);
	}
    }

}

sub is_instantiated_in {
    my($dbh) = @_;
    my $sth = $dbh->prepare(
	'select c1.id,c2.id '.
	'from nodes,node2class,classes c1,classes c2 '.
	'where nodes.id=node2class.node and c2.id=node2class.klass '.
	'and c1.id=nodes.iklass') or croak($dbh->errstr);
    my $rv = $sth->execute or croak($dbh->errstr);
    my @is_instantiated_in;
    for (1..$sth->rows) {
	my($a, $b)  = $sth->fetchrow_array;
	push @is_instantiated_in, [$a, $b];
    }
    croak "The class structure is cyclic." if is_cyclic(@is_instantiated_in);
    return @is_instantiated_in;
}

# check for cycles, http://www.cs.hmc.edu/~keller/courses/cs60/s98/examples/acyclic/
sub is_cyclic {
    my %nodes;
    my @links;
    for my $l (@_) {
	$nodes{$l->[0]} = 1;
	$nodes{$l->[1]} = 1;
	push @links, [$l->[0], $l->[1]];
    }
    while (1) {
	my @nodes = keys %nodes;
	return unless @nodes; # is acyclic
	my %non_leaves;
	for my $l (@links) {
	    $non_leaves{$l->[0]} = 1; # is not a leaf
	}
	my $has_leaf;
	for my $leaf (@nodes) {
	    next if $non_leaves{$leaf};
	    $has_leaf = 1;
	    delete $nodes{$leaf};
	    my @new_links;
	    for my $l (@links) {
		next if $l->[1] == $leaf;
		push @new_links, $l;
	    }
	    @links = @new_links;
	}
	return 1 unless $has_leaf; # is cyclic
    }
}

sub instantiated_in {
    my($class_id, $is_instantiated_in) = @_;
    my @return = ();
    for my $is_instantiated_in (@$is_instantiated_in) {
	push @return, $is_instantiated_in->[0] if $is_instantiated_in->[1] == $class_id;
    }
    for my $a (@return) {
	push @return, instantiated_in($a, $is_instantiated_in);
    }
    return @return;
}

package Hugin::Domain;
use Carp;

# Compute the probability of a scenario (given as a parameter) as a
# product of scenario node probabilities. The algorithm retrieves
# scenario node probabilities one by one, instantiating each scenario
# node to the specified scenario state before proceeding to the next
# node. The algorithm maintains the soft evidence and observes hard
# evidence in the scenario nodes.
sub scenario_probability {
    my($self, %scenario) = @_;
    my %likelihoods;
    my %retract;
    my $p;
    my @nodes = $self->get_nodes;
    for my $i (0..$#nodes) {
        $self->compile unless $self->is_compiled;
        $self->propagate('sum', 'normal');
        my $n = $nodes[$i];
        my $name = $n->get_label || $n->get_name;
        #croak "$name not in scenario" unless $scenario{$name};
        next unless $scenario{$name};
        my @states;
        if ($n->get_subtype eq 'interval') {
            for my $s ($n->get_state_values) {
                $s->[1] = 'inf' if $s->[1] > 1e+100;
                push @states, "[$s->[0],$s->[1])";
            }
        } else {
            @states = $n->get_state_labels;
        }
        my $state;
        for my $i (0..$#states) {
            $state = $i, last if $scenario{$name} eq $states[$i];
        }
        croak "node $name does not have state $scenario{$name} in scenario, it has '@states'" 
            unless defined $state;
        my @b = $n->get_beliefs;
        #print STDERR "$name: p=$b[$state]\n";
        $p = defined $p ? $p*$b[$state] : $b[$state];

        last if $i == $#nodes;
        
        my $f1 = $n->evidence_is_entered;
        my $f2 = $n->likelihood_is_entered;
        my $instantiated = 0;

        #my @f = $n->get_entered_findings;
        #print STDERR "evidence $name ($f1,$f2): @f\n";
        
        if (not $f1 and not $f2) {
            $retract{$name} = 1;
        } elsif ($f1 and not $f2) {
            $instantiated = 1;
        } elsif ($f1 and $f2) {
            $likelihoods{$name} = [$n->get_entered_findings];
        } else {
            # should not get here
            croak "node $name has likelihood but not evidence??";
        }

        #last if $i == $#nodes;
        $n->select_state($state) unless $instantiated;
    }

    # restore

    for my $n ($self->get_nodes) {
        my $name = $n->get_label || $n->get_name;
        $n->retract_findings if $retract{$name};
        $n->enter_findings(@{$likelihoods{$name}}) if $likelihoods{$name};
    }

    return $p;
}

package Hugin::Node;
use Carp;

sub to_db {
    my($self, $dbh) = @_;
    my $label = $self->get_label;
    $label =~ s/\n/\\n/g;
    my @position = $self->get_position;
    my $subtype = $self->get_subtype;
    my @states = ($subtype eq 'interval' or $subtype eq 'number') ? 
	$self->get_state_values : $self->get_state_labels;
    for (@states) {
	$_ =~ s/"/\\\\"/g;
	$_ = '['.($_->[0]<-1E300?'-inf':$_->[0]).','.($_->[1]>1E300?'inf':$_->[1]).')' if ref;
    }
    my $table = $self->get_table;
    
    my $model_nodes = 'NULL';
    my $model_data = 'NULL';
    my $model = $self->get_model;

    my @data = $table->get_data if $table and !$model;
    my $iclass = $self->get_instance_class;
    
    if ($model) {
	my @n;
	for my $n ($model->get_nodes) {
	    push @n, $n->get_name;
	}
	$model_nodes = "'".join(',', @n)."'";
	@n = ();
	for my $i (0..$model->get_size-1) {
	    my $e = $model->get_expression($i);
	    push @n, $e->to_string;
	}
	$model_data = "'".join(',', @n)."'";
    }

    $dbh->do("insert into nodes (name,category,kind,subtype,label,position,states,cpt,model_nodes,model_data) values (".
	     "'".$self->get_name."',".
	     "'".$self->get_category."',".
	     "'".$self->get_kind."',".
	     "'".$subtype."',".
	     "E'".$label."',".
	     "'{$position[0],$position[1]}',".
	     "E'{\"".join('","',@states)."\"}',".
	     "'{".join(',',@data)."}',".
	     $model_nodes.",".
	     $model_data.')'
	) or croak($dbh->errstr);
    
    my $sth = $dbh->prepare("select currval('nodes_id_seq')") or croak($dbh->errstr);
    my $rv = $sth->execute or croak($dbh->errstr);
    my($id) = $sth->fetchrow_array;

    my %attr = $self->get_attributes;
    for my $key (sort keys %attr) {
	my $val = $attr{$key};
	$val =~ s/\n/\\n/g;
	$val =~ s/'/\\'/g;
	$dbh->do("insert into node_attr (node,attr,value) values ".
		 "('$id', '$key', E'$val')") or croak($dbh->errstr);
    }
    return $id;
}

package Hugin;

# older DBD::Pg do not do this
sub row {
    my($sth) = @_;
    my @row = $sth->fetchrow_array;
    for (@row) {
	next unless $_;
	if (/^{/) {
	    s/^{//;
	    s/}$//;
	    my $a = $_;
	    my @a;
	    if ($a =~ /^{/) {
		$a =~ s/^{//;
		$a =~ s/}$//;
		my @b = split /\},\{/, $a;
		for my $x (@b) {
		    my @x = split /,/, $x;
		    for (@x) {
			s/^\"//;
			s/\"$//;
		    }
		    push @a, \@x;
		}
	    } else {
		if ($a =~ /\"/) {
		    $a =~ s/\",(\w)/\",\"$1/g;
		    $a =~ s/(\w),\"/$1\",\"/g;
		    $a =~ s/^\"//;
		    $a =~ s/\"$//;
		    @a = split /\",\"/, $a;
		} else {
		    @a = split /,/, $a;
		}
	    }
	    $_ = \@a;
	}
    }
    return @row;
}

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Hugin - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Hugin;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Hugin, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.



=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

Ari Jolma, E<lt>ajolma@E<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010 by Ari Jolma

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.


=cut
