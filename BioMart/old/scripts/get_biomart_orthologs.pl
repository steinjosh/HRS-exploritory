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
    --help how brief help and exit
    --man    Show full documentation

=head1 DESCRIPTION

Given a list gene id's in species1 retrieve from BioMart the corresponding orthologous genes in species2, print to standard output
=cut

use strict;
use LWP::UserAgent;
use Getopt::Long;
use Pod::Usage;

my ($sp1, $sp2, $sp1_gid_file);

GetOptions(
     's1|query_species=s' => \$sp1,
     's2|target_species=s' => \$sp2,
     'gene_list|query_gene_list=s' => \$sp1_gid_file, 
) or pod2usage(-verbose => 2);

pod2usage(-verbose => 2) unless $sp1;
pod2usage(-verbose => 2) unless $sp2;
pod2usage(-verbose => 2) unless $sp1_gid_file;

my $xml_query = get_xml_query($sp1, $sp2, $sp1_gid_file);

my $path="http://www.biomart.org/biomart/martservice?";
my $request = HTTP::Request->new("POST",$path,HTTP::Headers->new(),'query='.$xml_query."\n");
my $ua = LWP::UserAgent->new;

my $response;

$ua->request($request, 
             sub{   
                 my($data, $response) = @_;
                 if ($response->is_success) {
                     print "$data";
                 }
                 else {
                     warn ("Problems with the web server: ".$response->status_line);
                 }
             },1000);



sub get_xml_query {
    my ($sp1, $sp2, $sp1_gid_file) = @_;
    my $biomart_root_sp = get_biomart_root_sp();
    
    $sp1 = $biomart_root_sp->{$sp1};
    $sp2 = $biomart_root_sp->{$sp2};
    
    my @gids;
    open my $IN, "<$sp1_gid_file" or die "cannot open $sp1_gid_file:$!\n";
    while(<$IN>){
        chomp;
	split;
	push @gids, $_[0];
    }
    close $IN;
    
    my $gid_list = join(",", @gids);

    my $xml_query = 
     '<?xml version="1.0" encoding="UTF-8"?>' . "\n" .
     '<!DOCTYPE Query>' . "\n" .
     '<Query  virtualSchemaName = "default" formatter = "TSV" header = "0" uniqueRows = "0" count = "" datasetConfigVersion = "0.7" >' . "\n" .                      
          '<Dataset name = "' . $sp1 . '_gene" interface = "default" >' . "\n" .
                '<Filter name = "ensembl_gene_id" value = "' . $gid_list .'"/>' . "\n" .
                '<Attribute name = "ensembl_gene_id" />' . "\n" .
                '<Attribute name = "' . $sp2 . '_gene" />' . "\n" .
                '<Attribute name = "' . $sp2 . '_orthology_type" />' . "\n" .
                '<Attribute name = "' . $sp2 . '_homolog_perc_id" />' . "\n" .
                '<Attribute name = "' . $sp2 . '_homolog_perc_id_r1" />' . "\n" .
        '</Dataset>' . "\n" .
     '</Query>' . "\n";

    return $xml_query;
}

sub get_biomart_root_sp {
    my %biomart_root_sp = (
        oryza_brachyantha           => 'obrachyantha_eg',
        arabidopsis_lyrata          => 'alyrata_eg',
        populus_trichocarpa         => 'ptrichocarpa_eg',
        brassica_rapa               => 'brapa_eg',
        vitis_vinifera              => 'vvinifera_eg',
        setaria_italica             => 'sitalica_eg',
        zea_mays                    => 'zmays_eg',
        solanum_lycopersicum        => 'slycopersicum_eg',
        physcomitrella_patens       => 'ppatens_eg',
        chlamydomonas_reinhardtii   => 'creinhardtii_eg',
        glycine_max                 => 'gmax_eg',
        sorghum_bicolor             => 'sbicolor_eg',
        brachypodium_distachyon     => 'bdistachyon_eg',
        oryza_sativa_indica         => 'oindica_eg',
        selaginella_moellendorffii  => 'smoellendorffii_eg',
        cyanidioschyzon_merolae     => 'cmerolae_eg',
        oryza_glaberrima            => 'oglaberrima_eg',
        arabidopsis_thaliana        => 'athaliana_eg',
        oryza_sativa                => 'osativa_eg',
    );
    return \%biomart_root_sp;
}
