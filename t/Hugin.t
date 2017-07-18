# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Hugin.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 5;
BEGIN { use_ok('Hugin') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

use Carp;

my $subtype = 'label';

my $d = Hugin::Domain->new();
$rain = $d->new_node('chance', 'discrete');
$rain->set_subtype($subtype);
$rain->set_name('Rain');
$rain->set_number_of_states(2);
$rain->set_state_labels('T', 'F');

# rain                      t    f
$rain->get_table->set_data(0.2, 0.8);

$sprinkler = $d->new_node('chance', 'discrete');
$sprinkler->set_subtype($subtype);
$sprinkler->set_name('Sprinkler');
$sprinkler->set_number_of_states(2);
$sprinkler->set_state_labels('T', 'F');
$sprinkler->add_parent($rain);

# rain                            T     T     T    T                      
# sprinkler                       T     F     T    F
$sprinkler->get_table->set_data(0.01, 0.99, 0.4, 0.6);

$grass_wet = $d->new_node('chance', 'discrete');
$grass_wet->set_subtype($subtype);
$grass_wet->set_name('Grass_wet');
$grass_wet->set_number_of_states(2);
$grass_wet->set_state_labels('T', 'F');
$grass_wet->add_parent($rain);
$grass_wet->add_parent($sprinkler);

# sprinkler                       T     T     T    T    F    F  F  F
# rain                            T     T     F    F    T    T  F  F         
# grass_wet                       T     F     T    F    T    F  T  F
$grass_wet->get_table->set_data(0.99, 0.01, 0.9, 0.1, 0.8, 0.2, 0, 1);

$d->compile;
$d->propagate('sum', 'normal');

my @bels = $grass_wet->get_beliefs();
for (@bels) {
    $_ *= 100;
    $_ = sprintf("%.2f", $_);
}
is_deeply(\@bels, [44.84, 55.16], "Grass wet beliefs: @bels vs 44.84, 55.16");

$rain->select_state(0);
$d->propagate('sum', 'normal');
@bels = $grass_wet->get_beliefs();
for (@bels) {
    $_ *= 100;
    $_ = sprintf("%.2f", $_);
}
is_deeply(\@bels, [80.19, 19.81], "Grass wet beliefs when rain is observed: @bels vs 80.19 19.81");

$rain->enter_findings(0.98, 0.51);
$d->propagate('sum', 'normal');
@bels = $grass_wet->get_beliefs();
for (@bels) {
    $_ *= 100;
    $_ = sprintf("%.2f", $_);
}
is_deeply(\@bels, [50.34, 49.66], "Grass wet beliefs when the likelihood of rain is 0.98 0.51: @bels vs 50.34 49.66");

my %scenario = (
    Rain => 'T', 
    Sprinkler => 'T',
    Grass_wet => 'T'
    );
my $sum = 0;
while (1) {
    my $p = $d->scenario_probability(%scenario);
    $sum += $p;
    if ($scenario{Rain} eq 'T') {
        $scenario{Rain} = 'F';
    } else {
        $scenario{Rain} = 'T';
        if ($scenario{Sprinkler} eq 'T') {
            $scenario{Sprinkler} = 'F';
        } else {
            $scenario{Sprinkler} = 'T';
            if ($scenario{Grass_wet} eq 'T') {
                $scenario{Grass_wet} = 'F';
            } else {
                last;
            }
        }
    }
}
ok(abs($sum-1) < 0.01, "sum of scenario probabilities: $sum should be ~ 1");
