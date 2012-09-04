#! /usr/bin/env perl

=pod

=head1 NAME

get_biomart_orthologs.pl : given list of genes in species1, get corresponding orthologs in species2

=head1 SYNOPSIS

get_biomart_orthologs.pl --species1 sorghum --species2 rice --species1_gene_list_file <file>

Options:

    --query_species e.g. 'sorghum_bicolor'
    --target_species e.g. 'oryza_sativa'
    --query_gene_list file containing list of species1 gene id's 
    --json output of scan_biomart.pl (e.g. biomart_homologs.json)
    --help how brief help and exit
    --man    Show full documentation

=head1 DESCRIPTION

Given a list gene id's in species1 retrieve from BioMart the corresponding orthologous genes in species2, print to standard output
=cut

use strict;
use LWP::UserAgent;
use Getopt::Long;
use JSON;
use Pod::Usage;
use Data::Dumper;

my ($sp1, $sp2, $sp1_gid_file, $json_file);

GetOptions(
     's1|query_species=s' => \$sp1,
     's2|target_species=s' => \$sp2,
     'gene_list|query_gene_list=s' => \$sp1_gid_file,
     'json=s' => \$json_file, 
) or pod2usage(-verbose => 2);

pod2usage(-verbose => 2) unless $sp1;
pod2usage(-verbose => 2) unless $sp2;
pod2usage(-verbose => 2) unless $sp1_gid_file;

my $gid_list = get_gene_list($sp1_gid_file);

my $biomart_parameters = get_biomart_parameters($json_file, $sp1, $sp2);

for my $set (@$biomart_parameters){
    my ($parameters, $metas) = @$set;
    my $xml_query = get_xml_query($parameters, $gid_list);
    query_biomart($xml_query);
    
    for my $meta (@$metas){
        print_metadata($meta);
    }
}

#my $xml_query; # = get_xml_query($json_file, $sp1, $sp2, $sp1_gid_file);

#open_json($json_file);

sub query_biomart {
    my $xml_query = shift;
    my $path="http://www.biomart.org/biomart/martservice?";
    my $request = HTTP::Request->new("POST",$path,HTTP::Headers->new(),
                                     'query='.$xml_query."\n");
    my $ua = LWP::UserAgent->new;

    my $response;
    
    my $outfile = 'biomart_out.txt';
    open my $OUT, ">>$outfile" or die "cannot open $outfile:$!\n";

    $ua->request($request, 
         sub{   
             my($data, $response) = @_;
             if ($response->is_success) {
                 print $OUT "$data";
             }
             else {
                 warn ("Problems with the web server: ".$response->status_line);
             }
         },1000);
}


sub get_xml_query {
    my ($parameters, $gid_list) = @_;
    
    my ($query_set, $target_set, @attributes) = @$parameters;

    my $xml_query = 
        '<?xml version="1.0" encoding="UTF-8"?>' . "\n" .
        '<!DOCTYPE Query>' . "\n" .
        '<Query  virtualSchemaName = "default" formatter = "TSV" header = "1" ' .
        'uniqueRows = "1" count = "" datasetConfigVersion = "0.7" >' . "\n" .                      
        '<Dataset name = "' . $query_set . '" interface = "default" >' . "\n" .
        '<Filter name = "ensembl_gene_id" value = "' . $gid_list .'"/>' . "\n" .
        '<Attribute name = "ensembl_gene_id" />' . "\n" .
        '<Attribute name = "' . $target_set . '" />' . "\n";
                
    for my $attribute (sort @attributes){	
	$xml_query .= '<Attribute name = "' . $attribute . '" />' . "\n";
    }
    
    $xml_query .= '</Dataset>' . "\n" . '</Query>' . "\n";

    return $xml_query;
}


sub get_biomart_parameters {
    my ($json_file, $sp1, $sp2) = @_;
    
    my @biomart_parameters;

    open my $IN, "<$json_file" or die "cannot open $json_file:$!\n";
    my $json_text = <$IN>;   
    my $biomart_info = decode_json($json_text);
    
    my @dataset_pairs = @{$biomart_info->{query}->{$sp1}->{$sp2}};
    for my $dataset_pair (@dataset_pairs){
        my ($query_dataset, $target_dataset) = @$dataset_pair;
	my @target_attributes 
	    = @{$biomart_info->{targetAttributes}->{$target_dataset}};
        
	my %queryset_meta = %{$biomart_info->{datasetMeta}->{$query_dataset}};
	my %targetset_meta = %{$biomart_info->{datasetMeta}->{$target_dataset}};
	
	my $mart_name = $queryset_meta{martName};
	
	my %mart_meta = %{$biomart_info->{martRegistry}->{$mart_name}};
	
	push my @parameters, $query_dataset, $target_dataset, @target_attributes;
	push my @metas, \%queryset_meta, \%targetset_meta, \%mart_meta;
	
	push my @set, \@parameters, \@metas;
	
	push @biomart_parameters, \@set;
    }
    return \@biomart_parameters;
}

sub print_metadata {
    my $meta = shift;
    my $outfile = 'biomart_metadata.txt';
    open my $OUT, ">>$outfile" or die "cannot open $outfile:$!\n";
    while ( my ($key, $value) = each(%$meta) ) {
        print $OUT "$key\t$value\n";
    }
    print $OUT "\n";
}

sub get_gene_list {
    my $sp1_gid_file = shift;
	
    my @gids;
    open my $IN, "<$sp1_gid_file" or die "cannot open $sp1_gid_file:$!\n";
    while(<$IN>){
        chomp;
        split;
        push @gids, $_[0];
    }
    close $IN;
    
    my $gid_list = join(",", @gids);
    return $gid_list;
}
