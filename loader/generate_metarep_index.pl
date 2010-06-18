#! usr/local/bin/perl

##################################################################
# Description: generate_metarep_index.pl
# --------------
# Author: jgoll 
# Email:  jgoll@jcvi.org
# Date:   Mar 3, 2010  
##################################################################



BEGIN {
  #unshift(@INC, '/usr/local/scratch/jgoll/scripts/solr-parser/lib');	
  #unshift(@INC, '/local/annotation_metagenomic/METAREP/parser/lib');
  unshift(@INC, '/export/projects/metagenomics-reports/parsers/solr/lib');
}

use strict;
use File::Basename;
use Encode;
use utf8;
use Unicode::String;
use SolrIndexGenerator;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use Pod::Usage;

=head1 NAME
generate_metarep_index.pl let's you generate METAREP lucene indices 
			
B<--mode, -m>
	prok or viral

B<--project_dir, -p>
	project directory that contains several libraries
	
B<--project_id, -i>
	METAREP project id
 a directory for files containing all peptides from Shannon's hydrothermal vent project with their corresponding cluster id.

/usr/local/projects/GOSII/lzeigler/DeepSea/


B<--apis_db, -a>
	Apis MySQL database
	
=back

=head1 AUTHOR

Johannes Goll  C<< <jgoll@jcvi.org> >>

=cut



my %args = ();

#handle user arguments
GetOptions(
	\%args,                
	'version', 	
	'mode|m=s',
	'project_dir|p=s',
	'old_format|o',
	'project_id|i=s',
	'apis_db|a=s',
	'clean_names|c',
	'population_name|p=s',
	'virulence_file|v=s',
	'xml_only|x',
	'help|man|?',
) || pod2usage(2);


#print help
if ($args{help}) {
	
	pod2usage(-exitval => 1, -verbose => 1);
}

#handle pod usage
if (!defined($args{project_dir}) || !(-d $args{project_dir})) {
		pod2usage(
			-message =>
"\n\nERROR: A valid project directory needs to be defined.\n",
			-exitval => 1,
			-verbose => 1
		);
	}
elsif (!defined($args{mode})) {
	pod2usage(
		-message => "\n\nERROR: A mode needs to be defined.\n",
		-exitval => 1,
		-verbose => 1
	);
}
elsif (!defined($args{project_id})) {
	pod2usage(
		-message => "\n\nERROR: A project_id needs to be defined.\n",
		-exitval => 1,
		-verbose => 1
	);
}

#read command line arguments
my $mode			= $args{mode};
my $baseDir			= $args{project_dir};
my $projectId		= $args{project_id};
my $apisDatabase	= $args{apis_db};
my $population		= $args{population_name};
my $oldFormat		= $args{old_format};
my $cleanNames		= $args{clean_names};
my $virulenceFile	= $args{virulence_file};
my $xmlOnly			= $args{xml_only};


#$mode= 'viral';
#$apisDatabase = 'misc_apis';
#$apisDatabase = undef;

my $isViral = 0;

if($mode eq 'viral') {
	$isViral = 1;
}

#create indexer object
my $indexer = SolrIndexGenerator->new($projectId,$isViral,$apisDatabase,$population,$cleanNames,$xmlOnly);

opendir DIR,  $baseDir;
	
if($mode eq 'viral' || $mode eq 'prok')	 {
	
	my @libFiles = readdir(DIR);
	
	foreach my $libFile (@libFiles) {
		
		#if file is a directory
		if(-d "$baseDir/$libFile" ) {	
			
			#if file is not a . or .. directory
			if($libFile ne '.' && $libFile ne '..' ) {
				
				print "processing $baseDir/$libFile \n";
				
				
				if($mode eq 'viral') {
					my %files = ();	
					
					my ($annotationFile,$evidenceFile,$com2goFile,$filterFile,$clusterFile);
					
					#get latest evidence and annotation files
					if($oldFormat) {
						$annotationFile		= $indexer->clean(`ls -t $baseDir/$libFile/*.annotation | head -n 1`);
						$evidenceFile 		= $indexer->clean(`ls -t $baseDir/$libFile/*.evidence| head -n 1`);					
						$com2goFile 		= "$baseDir/$libFile/com2GO.go";
						$filterFile 		= "$baseDir/$libFile/filter/filter.tab";
						$clusterFile    	= "$baseDir/$libFile/clustering/cluster_id";
					}
					else {					
						#print "ls -t $baseDir/$libFile/viral_annotation/*.annotation | head -n 1 \n";
						$annotationFile		= $indexer->clean(`ls $baseDir/$libFile/viral_annotation/*.annotation`);
						$evidenceFile		= $indexer->clean(`ls -t $baseDir/$libFile/viral_annotation/*.evidence | head -n 1`);		
						$com2goFile			= $indexer->clean(`ls -t $baseDir/$libFile/viral_annotation/*.go | head -n 1`);	
						$filterFile 		= "$baseDir/$libFile/filter/filter.tab";	
						$clusterFile    	= "$baseDir/$libFile/clustering/cluster_id";
					}
					
					#must have files
					if(! (-e $annotationFile  || -e $annotationFile.".gz")) {
						die('Viral Annotation file $annotationFile does not exist\n');
					}
					else {
						$files{annotation} 	= $annotationFile;
					}
					if(! (-e $evidenceFile  || -e $evidenceFile.".gz")) {
						die('Viral Evidence file $evidenceFile does not exist\n');
					}
					else {
						$files{evidence} 	= $evidenceFile;
					}
									
					#optional files
					if(-e $com2goFile  || -e $com2goFile.".gz") {
						$files{com2go} 		= $com2goFile;
					}
					if(-e $filterFile  || -e $filterFile.".gz") {
						$files{filter} 		= $filterFile;
					}
					if(-e $clusterFile  || -e $clusterFile.".gz") {
						$files{cluster} = $clusterFile;
					}		
					if(-e $virulenceFile) {
						$files{virulence} = $virulenceFile;
					}	
					else {
						die('Virulence file $virulenceFile does not exist\n');
					}									
					
					#create hash reference
					my $files = \%files;	
					
					$indexer->createViralIndex($libFile,$files);				
				}
				elsif($mode eq 'prok' && -e "$baseDir/$libFile") {
					my %files = ();	
					
					my($annotationFile,$blastFile,$hmmFile,$filterFile,$clusterFile);
					
					if($oldFormat) {
						#IO
						$annotationFile	= $indexer->clean(`ls $baseDir/$libFile/camera_annotation_rules/*/camera_annotation_rules.default.stdout`);
						$blastFile 		= $indexer->clean(`ls $baseDir/$libFile/ncbi-blastp/*_default/output.btab`);
						
						if(! -e $blastFile) {
							
							$blastFile 	= $indexer->clean(`ls $baseDir/$libFile/ncbi-blastp/*_default/ncbi_blastp_btab.combined.out*`);
							print "Blast File ". $blastFile."\n";
							#die('no blast :'.$blastFile );
						}
						
						$hmmFile 		= $indexer->clean(`ls $baseDir/$libFile/ldhmmpfam/*_full_length/output.htab`);
						
						if(! -e $hmmFile) {		
							#die('no hmm');
							$hmmFile 		= $indexer->clean(`ls $baseDir/$libFile/ldhmmpfam/*_full_length/ldhmmpfam.htab.combined.out*`);
						}			
	#					$annotationFile	= $indexer->clean(`ls $baseDir/$libFile/camera_annotation_rules/*/camera_annotation_rules.default.stdout`);
	#					$blastFile 		= $indexer->clean(`ls $baseDir/$libFile/ncbi-blastp/*/ncbi_blastp_btab.combined.out`);
	#					$hmmFile 		= $indexer->clean(`ls $baseDir/$libFile/ldhmmpfam/*_full_length/ldhmmpfam.htab.combined.out`);
						$clusterFile    = "$baseDir/$libFile/clustering/cluster_id";					
					}
					else {
						my $annotationRoot = "/usr/local/projects/GOS3/Tier2/annotation/MAG-22-Priam-Update/gosII-indian-ocean";
	
						$annotationFile	= "$baseDir/$libFile/annotation/annotation_rules.combined.out";
						$blastFile 		= "$baseDir/$libFile/annotation/ncbi_blastp_btab.combined.out";
						$hmmFile 		= "$baseDir/$libFile/annotation/ldhmmpfam_full.htab.combined.out";
	#					
	#					$annotationFile	= "$annotationRoot/$libFile/annotation/annotation_rules.combined.out";
	#					$blastFile 		= "$annotationRoot/$libFile/annotation/ncbi_blastp_btab.combined.out";
	#					$hmmFile 		= "$annotationRoot/$libFile/annotation/ldhmmpfam_full.htab.combined.out";
						$filterFile 	= "$baseDir/$libFile/filter/filter.tab";
						$clusterFile    = "$baseDir/$libFile/clustering/cluster_id";
					}
				
					#must have files
					if(! (-e $annotationFile || -e $annotationFile.".gz")) {				
						next;
						die("Prok Annotation file '$annotationFile' does not exist\n");
					}
					else {
						$files{annotation} 	= $annotationFile;
					}
					if(! (-e $blastFile || -e $blastFile.".gz")) {
						
						next;
						die("Prok Blast file $blastFile does not exist\n");
					}
					else {
						$files{blast} 	= $blastFile;
					}
					if(! (-e $hmmFile || -e $hmmFile.".gz")) {
						next;
						die("Prok Hmm file $hmmFile does not exist\n");
					}
					else {
						$files{hmm} 	= $hmmFile;
					}
						
								
					#optional files
					if(-e $filterFile || -e $filterFile.".gz") {
						$files{filter} = $filterFile;
					}
					if(-e $clusterFile  || -e $clusterFile.".gz") {
						$files{cluster} = $clusterFile;
					}	
					$files{library_root} = "$baseDir/$libFile";			
								
					$indexer->createProkIndex($libFile,\%files);
				}
			}	
		}
	}
}
elsif($mode eq 'tab') {
	my @files = readdir(DIR);	
		
	foreach my $file (@files) {
		
		if($file ne '.' && $file ne '..' ) {
			my %files = ();	
			my $path = "$baseDir/$file";
			my($filename, undef, undef) = fileparse($path);	
					
			$files{tab} = $path;
			$indexer->createTabIndex($filename,\%files);
		}
	}
}



$indexer->close();






