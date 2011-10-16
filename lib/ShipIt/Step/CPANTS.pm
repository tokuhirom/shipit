package ShipIt::Step::CPANTS;
use strict;
use parent qw(ShipIt::Step);
 
use Module::CPANTS::Analyse 0.85;

my %IGNORE = map { $_ => 1 } qw(
    has_test_pod_coverage
    has_example
    has_separate_license_file
    uses_test_nowarnings
    has_version_in_each_file
    metayml_has_provides
);

sub run {
    my ($self, $state) = @_;
    my $ver = $state->version;

    if ($state->dry_run) {
        print "DRY-RUN.  CPANTS\n";
        return;
    }

    local $ENV{CPANTS_LINT} = 1;
    my $distfile = $state->distfile;
    my $mca = Module::CPANTS::Analyse->new(
        {
            dist => "$distfile",
            opts => {
                no_capture => 1
            },
        }
    );
    $mca->unpack and die "Cannot unpack : " . $mca->tarball;
    $mca->analyse;
    $mca->calc_kwalitee;

    {
        # build up lists of failed metrics
        my (@core_failure,@opt_failure,@exp_failure);
        my ($core_kw,$opt_kw)=(0,0);
        my $kwl=$mca->d->{kwalitee};
 
        my @need_db;
        foreach my $ind (@{$mca->mck->get_indicators}) {
            if ($ind->{needs_db}) {
                push(@need_db,$ind);
                next;
            }
            if ($IGNORE{$ind->{name}}) {
                push(@need_db, $ind);
                next;
            }
            if ($ind->{is_extra}) {
                next if $ind->{name} eq 'is_prereq';
                if ($kwl->{$ind->{name}}) {
                    $opt_kw++;
                } else {
                    push(@opt_failure,"* ".$ind->{name}."\n".$ind->{remedy});
                }
            }
            else {
                if ($kwl->{$ind->{name}}) {
                    $core_kw++;
                } else {
                    push(@core_failure,"* ".$ind->{name}."\n".$ind->{remedy});
                }
            }
        }

        # output results 
        my $output;
        $output.="Checked dist \t\t".$mca->tarball."\n";

        my $max_core_kw=$mca->mck->available_kwalitee;
        my $max_kw=$mca->mck->total_kwalitee;
        my $total_kw=$core_kw+$opt_kw;

        $output.="Kwalitee rating\t\t".sprintf("%.2f",100*$total_kw/$max_core_kw)."% ($total_kw/$max_core_kw)\n";
        if (@need_db) {
            $output.="Ignoring metrics\t".join(', ',map {$_->{name} } @need_db);
        }

        if ($total_kw == $max_kw - @need_db) {
            $output.="\nCongratulations for building a 'perfect' distribution!\n";
        } else {
            if (@core_failure) {
                $output.="\nHere is a list of failed Kwalitee tests and\nwhat you can do to solve them:\n\n";
                $output.=join ("\n\n",@core_failure,'');
            }
            if (@opt_failure) {
                $output.="\nFailed optional Kwalitee tests and\nwhat you can do to solve them:\n\n";
                $output.=join ("\n\n",@opt_failure,'');
            }
            if (@exp_failure) {
                $output.="\nFailed experimental Kwalitee tests and\nwhat you can do to solve them:\n\n";
                $output.=join ("\n\n",@exp_failure,'');
            }
        }
        print $output;
        print "\n";

        if (@core_failure) {
            exit(1);
        }
    }
}

1;
