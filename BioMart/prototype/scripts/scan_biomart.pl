#! /usr/bin/env perl

=pod

=head1 NAME

scan_biomart.pl Loads BioMart registry and scans attribute files to discover
    homolog attributes. Output is a json file representing a data structure
    containing meta information about available species homolog datasets
    See: http://www.biomart.org/martservice.html
    Currently works with Ensembl Genomes but not Ensembl main because the latter
    lacks appropriate metadata for the target species in "homologs" attributes
    This should be fixed in Ensembl release in October 2012.

=head1 SYNOPSIS

scan_biomart.pl

=head1 DESCRIPTION

Outputs a JSON file 'biomart_homologs.json'
=cut


use strict;
use LWP::Simple;
use XML::Simple;
use JSON;
use Data::Dumper;
use Pod::Usage;

my $scan = {};
my %attrib_type = ( homologs => 1,); # ortholog => 1,);
my $dataset_meta = {};
my $out_hash = {};
#my %filter = ( ensembl => 1, Ensembl156 => 1,); #if one wanted to exclude
my @want_attributes = qw(_homolog_perc_id _homolog_perc_id_r1 _orthology_type);

#For info on retrieving meta data see http://www.biomart.org/martservice.html
my $registry_url = "http://www.biomart.org/biomart/martservice?type=registry";
my $registry = get($registry_url);

my $registry_data = XMLin($registry);

for my $mart_name (keys %{$registry_data->{MartURLLocation}}){
    $registry_data->{MartURLLocation}->{$mart_name}->{name} = $mart_name;
    my $datasets = get_mart_datasets($mart_name);   
    my @datasets = split("\n", $datasets);
    
    for my $dataset (@datasets){    
        next unless $dataset =~ /TableSet/; #mart has two possible values for first field: TableSet and GenomicSequence
        my @dataset_fields = split("\t", $dataset);
	my $dataset_name = $dataset_fields[1];
	$scan->{martName}->{$dataset_name} = $mart_name;
#	$scan->{queryMeta}->{$dataset_name} = \@dataset_fields;
	$dataset_meta->{$dataset_name} = \@dataset_fields;
	
	my $attributes = get_dataset_attributes($dataset_name);
	my @attrib_lines = split("\n", $attributes);
	
	for my $attrib_line (@attrib_lines){
	    my @attrib_fields = split("\t", $attrib_line);
	    
	    if ($attrib_type{$attrib_fields[3]}){  #homologs
	        $scan->{query}->{$dataset_name} = 1;
		my $attrib_name = $attrib_fields[0];
		
		if ($attrib_name =~ /_gene$/ && 
		    $attrib_name !~ /_paralog_gene$/){
		    
		    (my $target_root = $attrib_name) =~ s/_gene$//;
		    $scan->{$dataset_name}->{targetName}->{$attrib_name} = 1;
		    $scan->{targetRoot}->{$attrib_name} = $target_root;
		}
		
		for my $attrib_match (@want_attributes){
		    if ($attrib_name =~ /$attrib_match$/){
		        (my $target_root = $attrib_name) =~ s/$attrib_match$//;
		        $scan->{attributes}->{$target_root}->{$attrib_name} = 1;
		    }		
		}
	    }	    
	}	
    }    
}

for my $dataset_name ( keys %{$scan->{query}} ){
    for my $target_name ( keys %{$scan->{$dataset_name}->{targetName}} ){
        next unless $scan->{query}->{$target_name}; #This excludes Ensembl main
	$scan->{keepDataset}->{$dataset_name} = 1;
	$scan->{keepDataset}->{$target_name}  = 1;
	$scan->{pair}->{$dataset_name}->{$target_name} = 1;
    }	
}

for my $dataset_name ( keys %{$scan->{keepDataset}} ){
    my $query_species = lc( $dataset_meta->{$dataset_name}->[2] );
    $query_species    =~ s/\s+genes .*//;
    
    my $assembly   = $dataset_meta->{$dataset_name}->[4];
    my $time_stamp = $dataset_meta->{$dataset_name}->[-1];
    my $mart_name  = $scan->{martName}->{$dataset_name};
    $scan->{keepMart}->{$mart_name} = 1;

    $out_hash->{datasetMeta}->{$dataset_name}->{species}   = $query_species;
    $out_hash->{datasetMeta}->{$dataset_name}->{timeStamp} = $time_stamp;
    $out_hash->{datasetMeta}->{$dataset_name}->{assembly}  = $assembly;
    $out_hash->{datasetMeta}->{$dataset_name}->{martName}  = $mart_name;
    
}    

for my $dataset_name (keys %{$scan->{pair}}){
    my $query_species = $out_hash->{datasetMeta}->{$dataset_name}->{species};

    for my $target_name ( keys %{$scan->{pair}->{$dataset_name}}){	
	my $target_species = $out_hash->{datasetMeta}->{$target_name}->{species};	
	my $target_root = $scan->{targetRoot}->{$target_name};
	my @attrib_names = keys %{$scan->{attributes}->{$target_root}};
	
	$out_hash->{targetAttributes}->{$target_name} = \@attrib_names;
	
	#Can in theory have species combinations from multiple biomarts
	#This will be the case once Ensembl main makes fixes so that dataset
	#and target names match
	push @{$out_hash->{query}->{$query_species}->{$target_species}},
	    [$dataset_name, $target_name,]; # @attrib_names];
    }   
}

for my $mart_name (keys %{$scan->{keepMart}}){
     $out_hash->{martRegistry}->{$mart_name}
         = \%{$registry_data->{MartURLLocation}->{$mart_name}};
}

my $json_text = encode_json $out_hash;

my $out_file = 'biomart_homologs.json';
open my $OUT, ">$out_file" or die "cannot open $out_file:$!\n";
print $OUT $json_text, "\n";

#For more readible output
my $dumper_out = 'biomart_homologs.dumper'; 
open my $OUT2, ">$dumper_out" or die "cannot open $dumper_out:$!\n";
print $OUT2 Dumper($out_hash);

sub print_mart_names {
    print join("\n", keys %{$registry_data->{MartURLLocation}}, ), "\n";
}

sub dump_registry {
    print Dumper($registry_data);
}

sub collect_db_meta {
    my $mart_name = shift;
    my %db_meta = %{$registry_data->{MartURLLocation}->{$mart_name}};
    my @parameters;
    push @parameters, 'name=' . '"' . $mart_name . '"';
    for my $key (sort keys %db_meta){
        push @parameters, $key . '=' . '"' . $db_meta{$key} . '"';
    }

}

sub get_dataset_attributes {
    my $set_name = shift;
    my $attributes;
    my $attributes_url =
        "http://www.biomart.org/biomart/martservice?type=attributes&dataset=$set_name&virtualSchema=default";
    $attributes = get($attributes_url);
    if ($attributes =~ /Problem retrieving/){
#        print STDERR "failed: $attributes_url\n$attributes\n";
	my $attributes_url =
            "http://www.biomart.org/biomart/martservice?type=attributes&dataset=$set_name";
#        print STDERR "\ntrying: $attributes_url\n";
	$attributes = get($attributes_url);
#	print "Ultimately failed $set_name\n" if $attributes =~ /Problem retrieving/;
	
    }
    return $attributes;
}

sub get_mart_datasets {
    my $mart_name = shift;
    my $datasets;
    my $datasets_url = 
        "http://www.biomart.org/biomart/martservice?type=datasets&mart=$mart_name";
    $datasets = get($datasets_url);
    if ($datasets =~ /virtualSchema/){
        #sometimes get an error which this different URL seems to fix
        my $datasets_url = 
            "http://www.biomart.org/biomart/martservice?type=datasets&mart=$mart_name&virtualSchema=default";
        $datasets = get($datasets_url);
    }
    return $datasets;
}

