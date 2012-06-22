#! /usr/bin/env perl

=pod

=head1 NAME

get_biomart_orthologs.pl : given list of genes in species1, get corresponding orthologs in species2

=head1 SYNOPSIS

get_biomart_orthologs.pl --species1 sorghum --species2 rice --species1_gene_list_file <file>

Options:

    --species1 e.g. 'sorghum'
    --species2 e.g. 'rice'
    --species1_gene_list file containing list of species1 gene id's 
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
     's1|species1=s' => \$sp1,
     's2|species2=s' => \$sp2,
     'gene_list|species1_gene_list=s' => \$sp1_gid_file, 
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

    my $xml_query;
    my $xml_files = xml_files();  #hash_ref of file names with input species as keys
    my $xml_file = $xml_files->{$sp1}->{$sp2};
    
    my $in_xml = './xml/' . $xml_file;    
    open my $IN_XML, "<$in_xml" or die "cannot open $in_xml\n";
    while(<$IN_XML>){
        $xml_query .= $_;
    }
    close $IN_XML;
    
    my @gids;
    open my $IN, "<$sp1_gid_file" or die "cannot open $sp1_gid_file:$!\n";
    while(<$IN>){
        chomp;
	split;
	push @gids, $_[0];
    }
    close $IN;
    
    #Insert gene list into xml query; dummy string'my_gene_list' gets replaced
    my $gene_list = join(",", @gids);
    $xml_query =~ s/my_gene_list/$gene_list/;
    return $xml_query;
}

sub xml_files {
    #canned xml files for each species pair combination are available 
    #as templates for customizing queries 
    my %xml_files = (
        rice => {
	    brachypodium => 'rice_brachypodium.xml',
	    sorghum => 'rice_sorghum.xml',
	    maize => 'rice_maize.xml',
	},
	brachypodium => {
	    rice => 'brachypodium_rice.xml',
	    sorghum => 'brachypodium_sorghum.xml',
	    maize => 'brachypodium_maize.xml',
	},
	sorghum => {
	    rice => 'sorghum_rice.xml',
	    brachypodium => 'sorghum_brachypodium.xml',
	    maize => 'sorghum_maize.xml',
	},
	maize => {
	    rice => 'maize_rice.xml',
	    brachypodium => 'maize_brachypodium.xml',
	    sorghum => 'maize_sorghum.xml',
	},
    );
    return \%xml_files;
}
