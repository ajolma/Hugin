#include "hugin.h"

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include "const-c.inc"

#if !defined(MIN) || !defined(MAX)
#define MIN(a,b)  ((a)<(b))?(a):(b)
#define MAX(a,b)  ((a)>(b))?(a):(b)
#endif

typedef h_class_collection_t Hugin_Collection;
typedef h_class_t Hugin_Class;
typedef h_domain_t Hugin_Domain;
typedef h_node_t Hugin_Node;
typedef h_expression_t Hugin_Expression;
typedef h_model_t Hugin_Model;
typedef h_table_t Hugin_Table;

void error_handler (h_location_t line_no, h_string_t message, void *data)
{
    if (strncmp(message, "warning:", 8) == 0)
        warn("Error at line %d: %s\n", line_no, message);
    else
        croak("Error at line %d: %s\n", line_no, message);
}

void print_error (void)
{
    croak("Error: %s\n", h_error_description (h_error_code ()));
}

typedef struct {
    h_node_category_t key;
    char *val;
} node_category_item;

#define n_node_categories 5

node_category_item node_categories[] = {
     {h_category_error, (char *)"error"},
     {h_category_chance, (char *)"chance"},
     {h_category_decision, (char *)"decision"},
     {h_category_utility, (char *)"utility"},
     {h_category_instance, (char *)"instance"}
     };

h_node_category_t node_category_e(char *node_category) {
    for (int i = 0; i < n_node_categories; i++) {
    	  if (strcmp(node_categories[i].val, node_category) == 0) return (node_categories[i].key);
    }
    croak("%s: is not a node category", node_category);
}

char *node_category_s(h_node_category_t node_category) {
    for (int i = 0; i < n_node_categories; i++) {
    	  if (node_categories[i].key == node_category) return (node_categories[i].val);
    }
    croak("%i: is not a node category", node_category);
}

#define n_node_kinds 4

typedef struct {
    h_node_kind_t key;
    char *val;
} node_kind_item;

node_kind_item node_kinds[] = {
     {h_kind_error, (char *)"error"},
     {h_unused, (char *)"unused"},
     {h_kind_discrete, (char *)"discrete"},
     {h_kind_continuous, (char *)"continuous"}
     };

h_node_kind_t node_kind_e(char *node_kind) {
    for (int i = 0; i < n_node_kinds; i++) {
    	  if (strcmp(node_kinds[i].val, node_kind) == 0) return (node_kinds[i].key);
    }
    croak("%s: is not a node kind", node_kind);
}

char *node_kind_s(h_node_kind_t node_kind) {
    for (int i = 0; i < n_node_kinds; i++) {
    	  if (node_kinds[i].key == node_kind) return (node_kinds[i].val);
    }
    croak("%i: is not a node kind", node_kind);
}

#define n_equilibriums 2

typedef struct {
    h_equilibrium_t key;
    char *val;
} equilibrium_item;

equilibrium_item equilibriums[] = {
     {h_equilibrium_sum, (char *)"sum"},
     {h_equilibrium_max, (char *)"max"}
     };

h_equilibrium_t equilibrium_e(char *equilibrium) {
    for (int i = 0; i < n_equilibriums; i++) {
    	  if (strcmp(equilibriums[i].val, equilibrium) == 0) return (equilibriums[i].key);
    }
    croak("%s: is not an equilibrium", equilibrium);
}

char *equilibrium_s(h_equilibrium_t equilibrium) {
    for (int i = 0; i < n_equilibriums; i++) {
    	  if (equilibriums[i].key == equilibrium) return (equilibriums[i].val);
    }
    croak("%i: is not an equilibrium", equilibrium);
}

#define n_evidence_modes 2

typedef struct {
    h_evidence_mode_t key;
    char *val;
} evidence_mode_item;

evidence_mode_item evidence_modes[] = {
     {h_mode_normal, (char *)"normal"},
     {h_mode_fast_retraction, (char *)"fast_rectraction"}
     };

h_evidence_mode_t evidence_mode_e(char *evidence_mode) {
    for (int i = 0; i < n_evidence_modes; i++) {
    	  if (strcmp(evidence_modes[i].val, evidence_mode) == 0) return (evidence_modes[i].key);
    }
    croak("%s: is not an evidence_mode", evidence_mode);
}

char *evidence_mode_s(h_evidence_mode_t evidence_mode) {
    for (int i = 0; i < n_evidence_modes; i++) {
    	  if (evidence_modes[i].key == evidence_mode) return (evidence_modes[i].val);
    }
    croak("%i: is not an evidence_mode", evidence_mode);
}

void parse_classes(h_string_t name, h_class_collection_t cc, void *data)
{
    char *file_name = (char*)malloc(strlen((char*)data) + strlen(name) + 6);
    if (file_name == NULL)
        return;
    strcpy(file_name, (char*)data);
    strcat(file_name, name);
    strcat(file_name, ".oobn");
    h_net_parse_classes(file_name, cc, parse_classes, error_handler, data);
    free(file_name);
}

MODULE = Hugin		PACKAGE = Hugin

INCLUDE: const-xs.inc

MODULE = Hugin		PACKAGE = Hugin::Collection	      PREFIX = collection_

=pod

@class Hugin::Collection
@brief A collection of Hugin classes.

@cmethod Hugin::Collection new()
@return A new collection object.
=cut
Hugin_Collection collection_new(...)
        CODE:
		RETVAL = h_new_class_collection();
		if (RETVAL == NULL) {
		   croak("Error in new_class_collection: %s\n", h_error_description(h_error_code()));
		}
	OUTPUT:
		RETVAL

void collection_DESTROY(Hugin_Collection collection)
        CODE:
		h_status_t e = h_cc_delete(collection);
		if (e)
		   croak("Error in collection_delete: %s\n", h_error_description(e));

=pod

@method Hugin::Class new_class()
@brief Create a new class into the collection.
=cut
SV *collection_new_class(Hugin_Collection collection)
        CODE:
		h_class_t c = h_cc_new_class(collection);
		if (c == NULL)
		   croak("Error in collection_new_class: %s\n", h_error_description(h_error_code()));
		RETVAL = sv_setref_pv(newSViv(0), "Hugin::Class", c);
	OUTPUT:
		RETVAL

=pod

@method parse($directory, $name)
@brief Parse NET files containing classes.
=cut
void collection_parse(Hugin_Collection collection, char *directory, char *name)
        CODE:
		parse_classes(name, collection, directory);

=pod

@method save_as_net($filename)
@brief Save the collection into a NET file.
=cut
void collection_save_as_net(Hugin_Collection collection, char *filename)
        CODE:
		h_status_t e = h_cc_save_as_net(collection, filename);
		if (e)
		    croak("Error in cc_save_as_net: %s\n", h_error_description(e));


=pod

@method @get_classes()
@return The classes in this collection in a list.
=cut
void collection_get_classes(Hugin_Collection collection)
    	PPCODE:
		h_class_t *classes = h_cc_get_members(collection);
		int i = 0;
		for (h_class_t c = classes[i++]; c; c = classes[i++]) {
		    EXTEND(SP, 1);
		    PUSHs(sv_setref_pv(sv_2mortal(newSViv(0)), "Hugin::Class", c));
		}

=pod

@method Hugin::Class get_class_by_name($name)
@return A class or undef
=cut
SV *collection_get_class_by_name(Hugin_Collection collection, char *name)
        CODE:
		h_class_t c = h_cc_get_class_by_name(collection, name);
		if (c)
		    RETVAL = sv_setref_pv(newSViv(0), "Hugin::Class", c);
		else
		   croak("No such class in collection: %s\n", name);
	OUTPUT:
		RETVAL


MODULE = Hugin		PACKAGE = Hugin::Class	      PREFIX = class_

=pod

@class Hugin::Class
@brief An object-oriented Hugin model is a class.

@method Hugin::Collection get_collection()
@return The collection to which this class belongs to.
=cut
SV *class_get_collection(Hugin_Class c)
        CODE:
		h_class_collection_t cc = h_class_get_class_collection(c);
		if (cc == NULL)
		   croak("Error in class_collection: %s\n", h_error_description(h_error_code()));
		RETVAL = sv_setref_pv(sv_2mortal(newSViv(0)), "Hugin::Collection", cc);
	OUTPUT:
		RETVAL

=pod

@method delete()
@brief Remove this class from the collection.
=cut
void class_delete(Hugin_Class c)
        CODE:
		h_status_t e = h_class_delete(c);
		if (e)
		   croak("Error in class_delete: %s\n", h_error_description(e));

=pod

@method $get_name()
=cut
SV* class_get_name(Hugin_Class c)
    	CODE:
		if (c)
		    RETVAL = newSVpv(h_class_get_name(c), 0);
		else
		    RETVAL = &PL_sv_undef;
	OUTPUT:
		RETVAL

=pod

@method set_name($name)
=cut
void class_set_name(Hugin_Class c, char *name)
    	CODE:
		if (c)
		    h_class_set_name(c, name);

=pod

@method Hugin::Node new_node($category, $kind)
Category is "chance", "decision", "utility", or "instance". Kind
is either "discrete" or "continuous".
=cut
Hugin_Node class_new_node(Hugin_Class klass, char *category, char *kind)
	CODE:
		h_node_category_t c = node_category_e(category);
		h_node_kind_t k = node_kind_e(kind);
		h_node_t n = h_class_new_node(klass, c, k);
		RETVAL = n;
	OUTPUT:
		RETVAL

=pod

@method Hugin::Node get_node_by_name($name)
=cut
Hugin_Node class_get_node_by_name(Hugin_Class klass, char *name)
	CODE:
		h_node_t n = h_class_get_node_by_name(klass, name);
		RETVAL = n;
	OUTPUT:
		RETVAL


=pod

@method Hugin::Domain create_domain()
=cut
Hugin_Domain class_create_domain(Hugin_Class c)
	CODE:
		RETVAL = h_class_create_domain(c);
		if (RETVAL == NULL) {
		   croak("Error in class_create_domain: %s\n", h_error_description(h_error_code()));
		}
	OUTPUT:
		RETVAL

=pod

@method @get_node_size()
=cut
void class_get_node_size(Hugin_Class c)
    	PPCODE:
		size_t width, height;
		h_status_t e = h_class_get_node_size(c, &width, &height);
		if (!e) {
		    EXTEND(SP, 2);
  		    PUSHs(sv_2mortal(newSVnv(width)));
		    PUSHs(sv_2mortal(newSVnv(height)));
		} else
		    croak("Error in class_get_node_size: %s\n", h_error_description(e));

=pod

@method set_node_size()
=cut
void class_set_node_size(Hugin_Class c, size_t width, size_t height)
    	CODE:
		h_status_t e = h_class_set_node_size(c, width, height);
		if (e)
		    croak("Error in class_set_node_size: %s\n", h_error_description(e));

=pod

@method %get_attributes()
=cut
void class_get_attributes(Hugin_Class c)
    	PPCODE:
		for (h_attribute_t a = h_class_get_first_attribute(c); a; a = h_attribute_get_next(a)) {
		    SV *key = newSVpv(h_attribute_get_key(a), 0);
		    SV *val = newSVpv(h_attribute_get_value(a), 0);
  		    EXTEND(SP, 2);
		    PUSHs(sv_2mortal(key));
		    PUSHs(sv_2mortal(val));
		}

=pod

@method set_attribute($attribute, $value)
=cut
void class_set_attribute(Hugin_Class c, char *attribute, char *value)
    	CODE:
		h_status_t e = h_class_set_attribute(c, attribute, value);
		if (e) 
		    croak("Error in class_set_attribute: %s\n", h_error_description(e));

=pod

@method @get_nodes()
=cut
void class_get_nodes(Hugin_Class c)
       	PPCODE:
		for (Hugin_Node node = h_class_get_first_node(c); node; node = h_node_get_next(node)) {
		    EXTEND(SP, 1);
		    PUSHs(sv_setref_pv(sv_2mortal(newSViv(0)), "Hugin::Node", node));
		}

=pod

@method Hugin::Node new_instance()
=cut
Hugin_Node class_new_instance(Hugin_Class c1, Hugin_Class c2)
	CODE:
		RETVAL = h_class_new_instance(c1, c2);
	OUTPUT:
		RETVAL

=pod

@method @get_inputs()
=cut
void class_get_inputs(Hugin_Class c)
       	PPCODE:
		h_node_t *nodes = h_class_get_inputs(c);
		int i;
		for (i = 0; nodes[i]; i++) {
		    EXTEND(SP, 1);
		    PUSHs(sv_setref_pv(sv_2mortal(newSViv(0)), "Hugin::Node", nodes[i]));
		}

=pod

@method @get_outputs()
=cut
void class_get_outputs(Hugin_Class c)
       	PPCODE:
		h_node_t *nodes = h_class_get_outputs(c);
		int i;
		for (i = 0; nodes[i]; i++) {
		    EXTEND(SP, 1);
		    PUSHs(sv_setref_pv(sv_2mortal(newSViv(0)), "Hugin::Node", nodes[i]));
		}

MODULE = Hugin		PACKAGE = Hugin::Domain	      PREFIX = domain_

=pod

@class Hugin::Domain
@brief A runtime domain.

@cmethod Hugin_Domain new()
=cut
Hugin_Domain domain_new(void)
	CODE:
		h_domain_t domain = h_new_domain();
		RETVAL = domain;
	OUTPUT:
		RETVAL

=pod

@cmethod Hugin::Domain parse_net_file($filename)
=cut
Hugin_Domain domain_parse_net_file(char *file_name)
	CODE:
		h_domain_t domain = h_net_parse_domain(file_name, error_handler, NULL);
		if (domain == NULL)
		    print_error ();
		RETVAL = domain;
	OUTPUT:
		RETVAL

=pod

@method Hugin::Domain clone()
=cut
Hugin_Domain domain_clone(Hugin_Domain domain)
	CODE:
		RETVAL = h_domain_clone(domain);
		if (RETVAL == NULL) {
		   croak("Error in domain_clone: %s\n", h_error_description(h_error_code()));
		}
	OUTPUT:
		RETVAL

void domain_DESTROY(Hugin_Domain domain)
     	CODE:
		h_status_t e = h_domain_delete(domain);
		if (e)
		   croak("Error in domain_delete: %s\n", h_error_description(e));

=pod

@method Hugin::Node get_first_node()
=cut
Hugin_Node domain_get_first_node(Hugin_Domain domain)
	CODE:
		RETVAL = h_domain_get_first_node(domain);
	OUTPUT:
		RETVAL

=pod

@method @get_nodes()
=cut
void domain_get_nodes(Hugin_Domain domain)
    	PPCODE:
		for (Hugin_Node node = h_domain_get_first_node(domain); node; node = h_node_get_next(node)) {
		    EXTEND(SP, 1);
		    PUSHs(sv_setref_pv(sv_2mortal(newSViv(0)), "Hugin::Node", node));
		}

=pod

@method Hugin::Node new_node($category, $kind)
Category is "chance", "decision", "utility", or "instance". Kind
is either "discrete" or "continuous".
=cut
Hugin_Node domain_new_node(Hugin_Domain domain, char *category, char *kind)
	CODE:
		h_node_category_t c = node_category_e(category);
		h_node_kind_t k = node_kind_e(kind);
		h_node_t n = h_domain_new_node(domain, c, k);
		RETVAL = n;
	OUTPUT:
		RETVAL

=pod

@method Hugin::Node get_node_by_name($name)
=cut
Hugin_Node domain_get_node_by_name(Hugin_Domain domain, char *name)
    	CODE:
		RETVAL = h_domain_get_node_by_name(domain, name);
		if (RETVAL == NULL)
		   croak("Error in get_node_by_name: %s\n", h_error_description(h_error_code()));
	OUTPUT:
		RETVAL

=pod

@method @get_node_size()
=cut
void domain_get_node_size(Hugin_Domain d)
    	PPCODE:
		size_t width, height;
		h_status_t e = h_domain_get_node_size(d, &width, &height);
		if (!e) {
		    EXTEND(SP, 2);
  		    PUSHs(sv_2mortal(newSVnv(width)));
		    PUSHs(sv_2mortal(newSVnv(height)));
		} else
		    croak("Error in domain_get_node_size: %s\n", h_error_description(e));

=pod

@method %get_attributes()
=cut
void domain_get_attributes(Hugin_Domain d)
    	PPCODE:
		for (h_attribute_t a = h_domain_get_first_attribute(d); a; a = h_attribute_get_next(a)) {
		    SV *key = newSVpv(h_attribute_get_key(a), 0);
		    SV *val = newSVpv(h_attribute_get_value(a), 0);
  		    EXTEND(SP, 2);
		    PUSHs(sv_2mortal(key));
		    PUSHs(sv_2mortal(val));
		}

=pod

@method compile()
=cut
void domain_compile(Hugin_Domain domain)
    	CODE:
		h_status_t e = h_domain_compile(domain);
		if (e) {
		   croak("Error in domain_compile: %s\n", h_error_description(e));
		}

int domain_is_compiled(Hugin_Domain domain)
    	CODE:
		RETVAL = h_domain_is_compiled(domain);
	OUTPUT:
		RETVAL
    

=pod

@method retract_findings()
=cut
void domain_retract_findings(Hugin_Domain domain)
	CODE:
		h_status_t e = h_domain_retract_findings(domain);
		if (e)
		    croak("Error in domain_retract_findings: %s\n", h_error_description(e));

=pod

@method propagate($equilibrium, $evidence_mode)
Equilibrium is either "sum" or "max". Evidence_mode is either "normal"
or "fast_rectraction".
=cut
void domain_propagate(Hugin_Domain domain, char *equilibrium, char *evidence_mode)
	CODE:
		h_status_t e = h_domain_propagate(domain, equilibrium_e(equilibrium), evidence_mode_e(evidence_mode));
		if (e)
		    croak("Error in domain_propagate: %s\n", h_error_description(e));

=pod

@method $get_expected_utility()
=cut
double domain_get_expected_utility(Hugin_Domain domain)
    	CODE:
		RETVAL = h_domain_get_expected_utility(domain);
		h_status_t e = h_error_code();
		if (e)
		   croak("Error in domain_get_expected_utility: %s\n", h_error_description(e));
	OUTPUT:
		RETVAL

MODULE = Hugin		PACKAGE = Hugin::Node	      PREFIX = node_

=pod

@class Hugin::Node
@brief A node in a class or a domain.

@method Hugin::Domain get_domain()
=cut
Hugin_Domain node_get_domain(Hugin_Node node)
	CODE:
		h_domain_t domain = h_node_get_domain(node);
		RETVAL = domain;
	OUTPUT:
		RETVAL

=pod

@method Hugin::Class get_class()
=cut
Hugin_Class node_get_class(Hugin_Node node)
	CODE:
		h_class_t klass = h_node_get_home_class(node);
		RETVAL = klass;
	OUTPUT:
		RETVAL

=pod

@method Hugin::Class get_instance_class()
=cut
Hugin_Class node_get_instance_class(Hugin_Node node)
	CODE:
		h_class_t klass = h_node_get_instance_class(node);
		RETVAL = klass;
	OUTPUT:
		RETVAL

=pod

@method Hugin::Node get_instance()
=cut
Hugin_Node node_get_instance(Hugin_Node node)
	CODE:
		h_node_t n = h_node_get_instance(node);
		RETVAL = n;
	OUTPUT:
		RETVAL

=pod

@method add_to_outputs(Hugin::Node node)
=cut
void node_add_to_outputs(Hugin_Node node)
	CODE:
		h_status_t e = h_node_add_to_outputs(node);
		if (e)
		    croak("Error in add_to_outputs: %s\n", h_error_description(e));

=pod

@method Hugin::Node get_output(Hugin::Node output)
Return the output clone of the argument. The self has to be an
instance node and the argument a node within the actual class. The
returned node is a node in the class of the instance node.
=cut
Hugin_Node node_get_output(Hugin_Node instance, Hugin_Node output)
	CODE:
		h_node_t node = h_node_get_output(instance, output);
		RETVAL = node;
	OUTPUT:
		RETVAL

=pod

@method add_to_inputs(Hugin::Node node)
=cut
void node_add_to_inputs(Hugin_Node node)
	CODE:
		h_status_t e = h_node_add_to_inputs(node);
		if (e)
		    croak("Error in add_to_inputs: %s\n", h_error_description(e));

=pod

@method set_input(Hugin::Node input, Hugin::Node actual)
=cut
void node_set_input(Hugin_Node instance, Hugin_Node input, Hugin_Node actual)
	CODE:
		h_status_t e = h_node_set_input(instance, input, actual);
		if (e)
		    croak("Error in set_input: %s\n", h_error_description(e));

=pod

@method Hugin::Node get_input(Hugin::Node input)
Return the actual input node bound to the argument node. The self has
to be an instance node and the argument a node within the actual
class. The returned node is a node in the class of the instance node.
=cut
Hugin_Node node_get_input(Hugin_Node instance, Hugin_Node input)
	CODE:
		h_node_t node = h_node_get_input(instance, input);
		RETVAL = node;
	OUTPUT:
		RETVAL

=pod

@method $get_category()
=cut
SV *node_get_category(Hugin_Node node)
	CODE:
		RETVAL = newSVpv(node_category_s(h_node_get_category(node)), 0);
	OUTPUT:
		RETVAL

=pod

@method $get_kind()
=cut
SV *node_get_kind(Hugin_Node node)
	CODE:
		RETVAL = newSVpv(node_kind_s(h_node_get_kind(node)), 0);
	OUTPUT:
		RETVAL

=pod

@method $get_subtype()
Subtype is either "label", "boolean", "number" or "interval".
=cut
SV *node_get_subtype(Hugin_Node node)
   	CODE:
		switch(h_node_get_subtype(node)) {
		case h_subtype_label:
		     RETVAL = newSVpv("label", 0);
		     break;
		case h_subtype_boolean:
		     RETVAL = newSVpv("boolean", 0);
		     break;
		case h_subtype_number:
		     RETVAL = newSVpv("number", 0);
		     break;
		case h_subtype_interval:
		     RETVAL = newSVpv("interval", 0);
		     break;
		default:
		     RETVAL = newSVpv("error", 0);
		     break;
		}
	OUTPUT:
		RETVAL

=pod

@method set_subtype($subtype)
Subtype is either "label", "boolean", "number" or "interval".
=cut
void node_set_subtype(Hugin_Node node, char *subtype)
   	CODE:
		h_node_subtype_t t;
		if (strcmp(subtype, "label") == 0)
		   t = h_subtype_label;
		else if (strcmp(subtype, "boolean") == 0)
		   t = h_subtype_boolean;
		else if (strcmp(subtype, "number") == 0)
		   t = h_subtype_number;
		else if (strcmp(subtype, "interval") == 0)
		   t = h_subtype_interval;
		else 
		   croak("unknown node subtype: %s\n", subtype);
		h_status_t e = h_node_set_subtype(node, t);
		if (e)
		    croak("Error in node_set_subtype: %s\n", h_error_description(e));

=pod

@method add_parent(Hugin::Node parent)
=cut
void node_add_parent(Hugin_Node child, Hugin_Node parent)
	CODE:
		h_status_t e = h_node_add_parent(child, parent);
		if (e)
		    croak("Error in node_add_parent: %s\n", h_error_description(e));

=pod

@method remove_parent(Hugin::Node parent)
=cut
void node_remove_parent(Hugin_Node node, Hugin_Node parent)
	CODE:
		h_status_t e = h_node_remove_parent(node, parent);
		if (e)
		    croak("Error in node_remove_parent: %s\n", h_error_description(e));

=pod

@method switch_parent(Hugin::Node old_parent, Hugin::Node new_parent)
=cut
void node_switch_parent(Hugin_Node node, Hugin_Node old_parent, Hugin_Node new_parent)
	CODE:
		h_status_t e = h_node_switch_parent(node, old_parent, new_parent);
		if (e)
		    croak("Error in node_switch_parent: %s\n", h_error_description(e));

=pod

@method reverse_edge(Hugin::Node node)
=cut
void node_reverse_edge(Hugin_Node node1, Hugin_Node node2)
	CODE:
		h_status_t e = h_node_reverse_edge(node1, node2);
		if (e)
		    croak("Error in node_reverse_edge: %s\n", h_error_description(e));

=pod

@method @get_parents()
=cut
void node_get_parents(Hugin_Node node)
	PPCODE:
		h_node_t *parents = h_node_get_parents(node);
		if (parents)
		   for (int i = 0; parents[i]; i++) {
			EXTEND(SP, 1);
		    	PUSHs(sv_setref_pv(sv_2mortal(newSViv(0)), "Hugin::Node", parents[i]));
		   }

=pod

@method @get_children()
=cut
void node_get_children(Hugin_Node node)
	PPCODE:
		h_node_t *children = h_node_get_children(node);
		if (children)
		   for (int i = 0; children[i]; i++) {
			EXTEND(SP, 1);
		    	PUSHs(sv_setref_pv(sv_2mortal(newSViv(0)), "Hugin::Node", children[i]));
		   }

=pod

@method $get_label()
=cut
SV *node_get_label(Hugin_Node node)
	CODE:
		RETVAL = newSVpv(h_node_get_label(node), 0);
	OUTPUT:
		RETVAL

=pod

@method set_label($label)
=cut
void node_set_label(Hugin_Node node, char *label)
	CODE:
		h_status_t e = h_node_set_label(node, label);
		if (e)
		    croak("Error in node_set_label: %s\n", h_error_description(e));

=pod

@method @get_position()
=cut
void node_get_position(Hugin_Node node)
    	PPCODE:
		h_coordinate_t x, y;
		h_status_t e = h_node_get_position(node, &x, &y);
		if (e)
		    croak("Error in node_get_position: %s\n", h_error_description(e));
		EXTEND(SP, 2);
		PUSHs(sv_2mortal(newSVnv(x)));
		PUSHs(sv_2mortal(newSVnv(y)));

=pod

@method set_position($x, $y)
=cut
void node_set_position(Hugin_Node node, int x, int y)
    	PPCODE:
		h_status_t e = h_node_set_position(node, x, y);
		if (e)
		    croak("Error in node_set_position: %s\n", h_error_description(e));

=pod

@method %get_attributes()
=cut
void node_get_attributes(Hugin_Node node)
    	PPCODE:
		for (h_attribute_t a = h_node_get_first_attribute(node); a; a = h_attribute_get_next(a)) {
		    SV *key = newSVpv(h_attribute_get_key(a), 0);
		    SV *val = newSVpv(h_attribute_get_value(a), 0);
  		    EXTEND(SP, 2);
		    PUSHs(sv_2mortal(key));
		    PUSHs(sv_2mortal(val));
		}

=pod

@method set_attribute($attribute, $value)
=cut
void node_set_attribute(Hugin_Node c, char *attribute, char *value)
    	CODE:
		h_status_t e = h_node_set_attribute(c, attribute, value);
		if (e) 
		    croak("Error in node_set_attribute: %s\n", h_error_description(e));

=pod

@method delete()
@brief Remove this node from the class (collection) or domain.
=cut
void node_delete(Hugin_Node node)
	CODE:
		h_status_t e = h_node_delete(node);
		if (e)
		    croak("Error in node_delete: %s\n", h_error_description(e));

=pod

@method Hugin::Node get_next()
=cut
Hugin_Node node_get_next(Hugin_Node node)
	CODE:
		RETVAL = h_node_get_next(node);
	OUTPUT:
		RETVAL

=pod

@method $get_name()
=cut
SV *node_get_name(Hugin_Node node)
    	CODE:
		if (node)
		    RETVAL = newSVpv(h_node_get_name(node), 0);
		else
		    RETVAL = &PL_sv_undef;
	OUTPUT:
		RETVAL

=pod

@method set_name($name)
=cut
void node_set_name(Hugin_Node node, char *name)
    	CODE:
		h_status_t e = h_node_set_name(node, name);
		if (e)
		    croak("Error in node_set_name: %s\n", h_error_description(e));

=pod

@method $get_number_of_states()
=cut
int node_get_number_of_states(Hugin_Node node)
    	CODE:
		if (node)
		    RETVAL = h_node_get_number_of_states(node);
		else
		    RETVAL = -1;
	OUTPUT:
		RETVAL

=pod

@method set_number_of_states($n)
=cut
void node_set_number_of_states(Hugin_Node node, int n)
    	CODE:
		h_status_t e = h_node_set_number_of_states(node, n);
		if (e)
		    croak("Error in node_set_number_of_states: %s\n", h_error_description(e));

=pod

@method @get_state_labels()
=cut
void node_get_state_labels(Hugin_Node node)
        PPCODE:
		for (int i = 0; i < h_node_get_number_of_states(node); i++) {
		    EXTEND(SP, 1);
		    PUSHs(sv_2mortal(newSVpv( h_node_get_state_label(node, i), 0 )));
		}

=pod

@method set_state_labels(@labels)
=cut
void node_set_state_labels(Hugin_Node node, ...)
        CODE:
		int n = MIN(h_node_get_number_of_states(node), items-1);
		for (int i = 0; i < n; i++) {
		    char *label = SvPV_nolen(ST(1+i));
		    h_status_t e = h_node_set_state_label(node, i, label);
		    if (e)
		       croak("Error in node_set_state_label: %s\n", h_error_description(e));
		}

=pod

@method @get_state_values()
=cut
void node_get_state_values(Hugin_Node node)
        PPCODE:
		if (h_node_get_subtype(node) == h_subtype_interval)
		for (int i = 0; i < h_node_get_number_of_states(node); i++) {
		    EXTEND(SP, 1);
		    AV *av = newAV();
		    sv_2mortal((SV*)av);
		    av_push(av, newSVnv( h_node_get_state_value(node, i) ));
		    av_push(av, newSVnv( h_node_get_state_value(node, i+1) ));
		    PUSHs(newRV_inc((SV*)av));
		}
		else
		for (int i = 0; i < h_node_get_number_of_states(node); i++) {
		    EXTEND(SP, 1);
		    PUSHs(sv_2mortal(newSVnv( h_node_get_state_value(node, i) )));
		}

=pod

@method set_state_values(@values)
=cut
void node_set_state_values(Hugin_Node node, ...)
        CODE:
		int n = MIN(h_node_get_number_of_states(node), items-1);
		for (int i = 0; i < n; i++) {
		    double value = SvNV(ST(1+i));
		    h_status_t e = h_node_set_state_value(node, i, value);
		    if (e)
		       croak("Error in node_set_state_value: %s\n", h_error_description(e));
		}

=pod

@method $get_state_value($value, $state)
=cut
double node_get_state_value(Hugin_Node node, int state, double value)
    	CODE:
		RETVAL = h_node_get_state_value(node, state);
	OUTPUT:
		RETVAL

=pod

@method set_state_value($value, $state, $value)
=cut
void node_set_state_value(Hugin_Node node, int state, double value)
    	CODE:
		h_status_t e = h_node_set_state_value(node, state, value);
		if (e)
		    croak("Error in node_set_state_value: %s\n", h_error_description(e));

=pod

@method Hugin::Table get_table()
=cut
Hugin_Table node_get_table(Hugin_Node node)
    	CODE:
		h_table_t table = h_node_get_table(node);
		RETVAL = table;
	OUTPUT:
		RETVAL

=pod

@method $get_belief($state)
=cut
double node_get_belief(Hugin_Node node, int state)
    	CODE:
		RETVAL = h_node_get_belief(node, state);
	OUTPUT:
		RETVAL

=pod

@method @get_beliefs()
=cut
void node_get_beliefs(Hugin_Node node)
    	PPCODE:
		for (int i = 0; i < h_node_get_number_of_states(node); i++) {
		    EXTEND(SP, 1);
		    PUSHs(sv_2mortal(newSVnv(h_node_get_belief(node, i))));
		}

=pod

@method select_state($state)
=cut
void node_select_state(Hugin_Node node, int state)
	CODE:
		h_status_t e = h_node_select_state(node, state);
		if (e)
		    croak("Error in node_select_state: %s\n", h_error_description(e));

=pod

@method enter_finding($state, $value)
=cut
void node_enter_finding(Hugin_Node node, int state, double value)
	CODE:
		h_status_t e = h_node_enter_finding(node, state, value);
		if (e)
		    croak("Error in node_enter_finding: %s\n", h_error_description(e));

=pod

@method $get_entered_finding($state)
=cut
double node_get_entered_finding(Hugin_Node node, int state)
	CODE:
		RETVAL = h_node_get_entered_finding(node, state);
                if (RETVAL < 0) {
                   h_status_t e = h_error_code();
                   croak("Error in node_get_entered_finding: %s\n", h_error_description(e));
                }
        OUTPUT:
		RETVAL

=pod

@method $get_entered_value()
=cut
double node_get_entered_value(Hugin_Node node)
	CODE:
		RETVAL = h_node_get_entered_value(node);
                h_status_t e = h_error_code();
                if (e)
		    croak("Error in node_get_entered_value: %s\n", h_error_description(e));
        OUTPUT:
		RETVAL

=pod

@method $evidence_is_entered()
=cut
int node_evidence_is_entered(Hugin_Node node)
	CODE:
		RETVAL = h_node_evidence_is_entered(node) ? 1 : 0;
        OUTPUT:
		RETVAL

=pod

@method $likelihood_is_entered()
=cut
int node_likelihood_is_entered(Hugin_Node node)
	CODE:
		RETVAL = h_node_likelihood_is_entered(node) ? 1 : 0;
        OUTPUT:
		RETVAL

=pod

@method enter_findings(@values)
=cut
void node_enter_findings(Hugin_Node node, ...)
	CODE:
		int n = MIN(h_node_get_number_of_states(node), items-1);
		for (int i = 0; i < n; i++) {
		    double value = SvNV(ST(1+i));
		    h_status_t e = h_node_enter_finding(node, i, value);
		    if (e)
		       croak("Error in node_enter_finding: %s\n", h_error_description(e));
		}

=pod

@method @get_entered_findings()
=cut
void node_get_entered_findings(Hugin_Node node)
	PPCODE:
		int n = h_node_get_number_of_states(node);
		for (int i = 0; i < n; i++) {
                    h_number_t f = h_node_get_entered_finding(node, i);
                    if (f < 0) {
                        h_status_t e = h_error_code();
                        croak("Error in node_get_entered_findings: %s\n", h_error_description(e));
                    }
                    EXTEND(SP, 1);
                    PUSHs(sv_2mortal(newSVnv(f)));
		}

=pod

@method enter_value($value)
=cut
void node_enter_value(Hugin_Node node, double value)
	CODE:
		h_status_t e = h_node_enter_value(node, value);
		if (e)
		    croak("Error in node_enter_value: %s\n", h_error_description(e));

=pod

@method retract_findings()
=cut
void node_retract_findings(Hugin_Node node)
	CODE:
		h_status_t e = h_node_retract_findings(node);
		if (e)
		    croak("Error in node_retract_findings: %s\n", h_error_description(e));

=pod

@method $get_expected_utility($state = 0)
=cut
double node_get_expected_utility(Hugin_Node node, int state = 0)
    	CODE:
		RETVAL = h_node_get_expected_utility(node, state);
		h_status_t e = h_error_code();
		if (e)
		   croak("Error in node_get_expected_utility: %s\n", h_error_description(e));
	OUTPUT:
		RETVAL

=pod

@method Hugin::Expression make_expression()
=cut
Hugin_Expression node_make_expression(Hugin_Node node)
    	CODE:
		RETVAL = h_node_make_expression(node);
	OUTPUT:
		RETVAL

=pod

@method Hugin::Model new_model()
=cut
Hugin_Model node_new_model(Hugin_Node node, ...)
    	CODE:
		h_node_t *model_nodes = (h_node_t *)calloc(sizeof(h_node_t), items);
		for (int i = 0; i < items-1; i++) {
		    if (sv_derived_from(ST(i+1), "Hugin::Node")) {
	   	       IV tmp = SvIV((SV*)SvRV(ST(i+1)));
	   	       model_nodes[i] = INT2PTR(Hugin_Node, tmp);
	 	    } else
		       croak("array item %i is not of type Hugin::Node", i);
		}
		RETVAL = h_node_new_model(node, model_nodes);
		free(model_nodes);
	OUTPUT:
		RETVAL

=pod

@method Hugin::Model get_model()
=cut
Hugin_Model node_get_model(Hugin_Node node)
    	CODE:
		RETVAL = h_node_get_model(node);
	OUTPUT:
		RETVAL

MODULE = Hugin		PACKAGE = Hugin::Expression      PREFIX = expression_

=pod

@class Hugin::Expression
@brief An expression in a Hugin::Model.
=cut

void expression_DESTROY(Hugin_Expression ex)
    	CODE:
		h_status_t e = h_expression_delete(ex);
		if (e)
		       croak("Error in expression_delete: %s\n", h_error_description(e));


=pod

@method $to_string()
=cut
const char *expression_to_string(Hugin_Expression e)
    	CODE:
		RETVAL = h_expression_to_string(e);
	OUTPUT:
		RETVAL

MODULE = Hugin		PACKAGE = Hugin::Model      PREFIX = model_

=pod

@class Hugin::Model
@brief A method to compute a conditional probability table.

@method delete()
@brief Remove the model from the node.
=cut

void model_delete(Hugin_Model m)
    	CODE:
		h_status_t e = h_model_delete(m);
		if (e)
		       croak("Error in model_delete: %s\n", h_error_description(e));

=pod

@method Hugin::Expression expression_from_string($string)
=cut
Hugin_Expression model_expression_from_string(Hugin_Model m, char *s)
    	CODE:
		RETVAL = h_string_parse_expression(s, m, error_handler, NULL);
	OUTPUT:
		RETVAL

=pod

@method get_size()
=cut
size_t model_get_size(Hugin_Model m)
    	CODE:
		RETVAL = h_model_get_size(m);
	OUTPUT:
		RETVAL

=pod

@method @get_nodes()
=cut
void model_get_nodes(Hugin_Model m)
	PPCODE:
		h_node_t *nodes = h_model_get_nodes(m);
		if (nodes)
		   for (int i = 0; nodes[i]; i++) {
			EXTEND(SP, 1);
		    	PUSHs(sv_setref_pv(sv_2mortal(newSViv(0)), "Hugin::Node", nodes[i]));
		   }

=pod

@method Hugin::Expression get_expression($from_index)
=cut
Hugin_Expression model_get_expression(Hugin_Model m, size_t index)
    	CODE:
		RETVAL = h_model_get_expression(m, index);
	OUTPUT:
		RETVAL

=pod

@method set_expression($to_index, Hugin::Expression e)
=cut
void model_set_expression(Hugin_Model m, size_t index, Hugin_Expression e)
    	CODE:
		h_status_t err = h_model_set_expression(m, index, e);
		if (err)
		       croak("Error in model_set_expression: %s\n", h_error_description(err));


MODULE = Hugin		PACKAGE = Hugin::Table	      PREFIX = table_

=pod

@class Hugin::Table
@brief A conditional probability table.

@method @get_data()
=cut
void table_get_data(Hugin_Table table)
    	PPCODE:
		h_number_t *data = h_table_get_data(table);
		size_t n = h_table_get_size(table);
		if (GIMME_V == G_SCALAR) {
		   AV *av = newAV();		   
		   for (int i = 0; i < n; i++)
		       av_push(av, newSVnv( data[i] ));
		   EXTEND(SP, 1);
		   PUSHs(newRV_inc((SV*)av));
		} else {
		   for (int i = 0; i < n; i++) {
		       EXTEND(SP, 1);
		       PUSHs(sv_2mortal(newSVnv( data[i] )));
		   }
		}

=pod

@method set_data(@data)
=cut
void table_set_data(Hugin_Table table, ...)
    	PPCODE:
		h_number_t *data = h_table_get_data(table);
		int n = MIN(h_table_get_size(table), items-1);
		for (int i = 0; i < n; i++) {
		    h_number_t x = SvNV(ST(1+i));
		    data[i] = x;
		}
		h_node_t *nodes = h_table_get_nodes(table);
		int i = 0;
		if (nodes)
		for (Hugin_Node node = nodes[i++]; node; node = nodes[i++]) {
		    h_status_t e = h_node_touch_table(node);
		    if (e)
		       croak("Error in node_touch_table: %s\n", h_error_description(e));
		}

=pod

@method $get_index_from_configuration()
=cut
int table_get_index_from_configuration(Hugin_Table table)
    	CODE:
		size_t *configuration = NULL;
		RETVAL = h_table_get_index_from_configuration(table, configuration);
	OUTPUT:
		RETVAL				   

=pod

@method @get_nodes()
=cut
void table_get_nodes(Hugin_Table table)
    	PPCODE:
		h_node_t *nodes = h_table_get_nodes(table);
		int i = 0;
		if (nodes)
		for (Hugin_Node node = nodes[i++]; node; node = nodes[i++]) {
		    EXTEND(SP, 1);
		    PUSHs(sv_setref_pv(sv_2mortal(newSViv(0)), "Hugin::Node", node));
		}

void table_DESTROY(Hugin_Table table)
    	CODE:
		h_status_t e = h_table_delete(table);
		if (e)
		       croak("Error in node_touch_table: %s\n", h_error_description(e));