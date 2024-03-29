#!/usr/bin/perl -w
use strict;
die "Usage: $0  \"config_file\"   \"output_sh\"  " if (@ARGV < 2);
my $filein=$ARGV[0];
my $fileout=$ARGV[1];
my %SPEC;
open(IN,$filein) or die "Cannot open config_file $filein";
while (<IN>) {
    chomp;
    my @a=split("\t",$_);
    if ((scalar(@a) < 2) or ($a[0] eq "")) { next; }
    $SPEC{$a[0]}=$a[1];
}
close IN;
my $thread=1;
my $minJump=100;
my $maxJump=1000000;
my $minSSSum=10;
my $minSamplecnt=1;
my $minReadcnt=2;
my $MAS=30;
my $coverage=0.9;
my $Junc=6;
my $ER=0.05;
my $stranded="no";
my $pre_defined_circRNA="no";
# check if all parameters are set
if (!exists $SPEC{"BWA_folder"}) { die "BWA_folder must by specified in the config_file $filein";}
if (!exists $SPEC{"BWA_genome_Index"}) { die "BWA_genome_Index must by specified in the config_file $filein";}
if (!exists $SPEC{"BWA_genome_folder"}) { die "BWA_genome_folder must by specified in the config_file $filein";}
if (!exists $SPEC{"ACF_folder"}) { die "ACF_folder must by specified in the config_file $filein";}
if (!exists $SPEC{"CBR_folder"}) { die "CBR_folder must by specified in the config_file $filein";}
if (!exists $SPEC{"Agtf"}) { die "Agtf must by specified in the config_file $filein";}
if (!exists $SPEC{"UNMAP"}) { die "UNMAP must by specified in the config_file $filein";}
if (!exists $SPEC{"UNMAP_expr"}) { die "UNMAP_expr must by specified in the config_file $filein";}
if (!exists $SPEC{"Seq_len"}) { die "Seq_len must by specified in the config_file $filein";}
if (exists $SPEC{"Thread"}) { $thread=$SPEC{"Thread"}; }
if (exists $SPEC{"minJump"}) { $minJump=$SPEC{"minJump"}; }
if (exists $SPEC{"maxJump"}) { $maxJump=$SPEC{"maxJump"}; }
if (exists $SPEC{"minSplicingScore"}) { $minSSSum=$SPEC{"minSplicingScore"}; }
if (exists $SPEC{"minSampleCnt"}) { $minSamplecnt=$SPEC{"minSampleCnt"}; }
if (exists $SPEC{"minReadCnt"}) { $minReadcnt=$SPEC{"minReadCnt"}; }
if (exists $SPEC{"Thread"}) { $thread=$SPEC{"Thread"}; }
if (exists $SPEC{"minMappingQuality"}) { $MAS=$SPEC{"minMappingQuality"}; }
if (exists $SPEC{"Coverage"}) { $coverage=$SPEC{"Coverage"}; }
if (exists $SPEC{"minSpanJunc"}) { $Junc=$SPEC{"minSpanJunc"}; }
if (exists $SPEC{"ErrorRate"}) { $ER=$SPEC{"ErrorRate"}; }
if (exists $SPEC{"Strandness"}) { $stranded=$SPEC{"Strandness"}; }
if (exists $SPEC{"pre_defined_circle_bed"}) { $pre_defined_circRNA=$SPEC{"pre_defined_circle_bed"}; }


my $command="";
open(OUT, ">".$fileout) or die "Cannot open output_sh file $fileout";
print OUT "#!/bin/bash\n\n";
print OUT "#Step1\n";
print OUT "echo \"Step1 maping_the_unmapped_reads_to_genome Started\" \n";
$command=$SPEC{"BWA_folder"}."/bwa mem -t ".$thread." -k 16 -T 20 ".$SPEC{"BWA_genome_Index"}." ".$SPEC{"UNMAP"}." \> unmap.sam";
print OUT $command,"\n";
$command="perl ".$SPEC{"ACF_folder"}."/ACF_Step1.pl unmap.sam unmap.parsed $MAS $coverage";
print OUT $command,"\n";
#$command="perl ".$SPEC{"ACF_folder"}."/get_selected_fa_from_pool.pl unmap.parsed.UID ".$SPEC{"UNMAP"}." unmap.parsed.UID.fa";
$command="ln -s ".$SPEC{"UNMAP"}." unmap.parsed.UID.fa";
print OUT $command,"\n";
print OUT "echo \"Step1 maping_the_unmapped_reads_to_genome Finished\" \n\n\n";


print OUT "#Step2\n";
print OUT "echo \"Step2 find_circle_supporting_sequences Started\" \n";
$command="perl ".$SPEC{"ACF_folder"}."/ACF_Step2.pl ".$SPEC{"CBR_folder"}."/ unmap.parsed.2pp.S1 ".$SPEC{"BWA_genome_folder"}."/ unmap.parsed.2pp.S2";
print OUT $command,"\n";
$command="perl ".$SPEC{"ACF_folder"}."/ACF_Step2_MuSeg.pl ".$SPEC{"CBR_folder"}."/ unmap.parsed.segs ".$SPEC{"Agtf"}." ".$SPEC{"BWA_genome_folder"}."/ unmap.parsed.segs 10";
print OUT $command,"\n";
print OUT "echo \"Step2 find_circle_supporting_sequences Finished\" \n\n\n";


print OUT "#Step3\n";
print OUT "echo \"Step3 define_circle Started\" \n";
if ($pre_defined_circRNA eq "no"){
    $command="perl ".$SPEC{"ACF_folder"}."/ACF_Step3.pl unmap.parsed.2pp.S3 unmap.parsed.2pp.S2.sum";
    print OUT $command,"\n";
}
else {
    $command="perl ".$SPEC{"ACF_folder"}."/get_circRNA_from_bed.pl ".$pre_defined_circRNA;
    print OUT $command,"\n";
    $command="perl ".$SPEC{"ACF_folder"}."/ACF_Step3.pl unmap.parsed.2pp.S3 unmap.parsed.2pp.S2.sum pre_defined_circRNA.sum";
    print OUT $command,"\n";
}

$command="perl ".$SPEC{"ACF_folder"}."/ACF_Step3_MuSeg.pl unmap.parsed.2pp.S3 unmap.parsed.segs.S2";
print OUT $command,"\n";
print OUT "echo \"Step3 define_circle Finished\" \n\n\n";


print OUT "#Step4\n";
print OUT "echo \"Step4 annotate_select_and_make_pseudo_sequences_for_circles Started\" \n";
$command="perl ".$SPEC{"ACF_folder"}."/ACF_Step4.pl unmap.parsed.2pp.S3 ".$SPEC{"Agtf"}." circle_candidates 10 $minJump $maxJump $minSSSum";
print OUT $command,"\n";

$command="perl ".$SPEC{"ACF_folder"}."/ACF_Step4_MEA.pl circle_candidates_MEA ".$SPEC{"Agtf"}." circle_candidates_MEA";
print OUT $command,"\n";
$command="perl ".$SPEC{"ACF_folder"}."/get_split_exon_border_biotype_genename.pl circle_candidates_MEA.gtf circle_candidates_MEA.agtf";
print OUT $command,"\n";
$command="perl ".$SPEC{"ACF_folder"}."/get_seq_from_agtf.pl circle_candidates_MEA.agtf ".$SPEC{"BWA_genome_folder"}."/ circle_candidates_MEA.pseudo";
print OUT $command,"\n";
$command="perl ".$SPEC{"ACF_folder"}."/get_pseudo_circle.pl circle_candidates_MEA.pseudo.gene.fa circle_candidates_MEA.CL ".$SPEC{"Seq_len"};
print OUT $command,"\n";

$command="perl ".$SPEC{"ACF_folder"}."/ACF_Step4_CBR.pl circle_candidates_CBR ".$SPEC{"Agtf"}." circle_candidates_CBR";
print OUT $command,"\n";
$command="perl ".$SPEC{"ACF_folder"}."/get_seq_from_agtf.pl circle_candidates_CBR.agtf ".$SPEC{"BWA_genome_folder"}."/ circle_candidates_CBR.pseudo";
print OUT $command,"\n";
$command="perl ".$SPEC{"ACF_folder"}."/get_pseudo_circle.pl circle_candidates_CBR.pseudo.gene.fa circle_candidates_CBR.CL ".$SPEC{"Seq_len"};
print OUT $command,"\n";

$command="perl ".$SPEC{"ACF_folder"}."/get_pseudo_circle.pl unmap.parsed.segs.S2.novel.fa circle_candidates_MuS.CL ".$SPEC{"Seq_len"};
print OUT $command,"\n";
print OUT "echo \"Step4 annotate_select_and_make_pseudo_sequences_for_circles Finished\" \n\n\n";


print OUT "#Step5\n";
print OUT "echo \"Step5 caliberate_the_expression_of_circles Started\" \n";
$command=$SPEC{"BWA_folder"}."/bwa index circle_candidates_MEA.CL";
print OUT $command,"\n";
$command=$SPEC{"BWA_folder"}."/bwa index circle_candidates_CBR.CL";
print OUT $command,"\n";
$command=$SPEC{"BWA_folder"}."/bwa index circle_candidates_MuS.CL";
print OUT $command,"\n";

$command=$SPEC{"BWA_folder"}."/bwa mem -t ".$thread." -k 16 -T 20 circle_candidates_MEA.CL unmap.parsed.UID.fa \> circle_candidates_MEA.sam";
print OUT $command,"\n";
$command=$SPEC{"BWA_folder"}."/bwa mem -t ".$thread." -k 16 -T 20 circle_candidates_CBR.CL unmap.parsed.UID.fa \> circle_candidates_CBR.sam";
print OUT $command,"\n";
$command=$SPEC{"BWA_folder"}."/bwa mem -t ".$thread." -k 16 -T 20 circle_candidates_MuS.CL unmap.parsed.UID.fa \> circle_candidates_MuS.sam";
print OUT $command,"\n";

$command="perl ".$SPEC{"ACF_folder"}."/ACF_Step5.pl circle_candidates_MEA.sam circle_candidates_MEA.CL circle_candidates_MEA.p1 ".$SPEC{"Seq_len"}." $Junc $ER $stranded";
print OUT $command,"\n";
$command="perl ".$SPEC{"ACF_folder"}."/ACF_Step5.pl circle_candidates_CBR.sam circle_candidates_CBR.CL circle_candidates_CBR.p1 ".$SPEC{"Seq_len"}." $Junc $ER $stranded";
print OUT $command,"\n";
$command="perl ".$SPEC{"ACF_folder"}."/ACF_Step5.pl circle_candidates_MuS.sam circle_candidates_MuS.CL circle_candidates_MuS.p1 ".$SPEC{"Seq_len"}." $Junc $ER $stranded";
print OUT $command,"\n";

$command="perl ".$SPEC{"ACF_folder"}."/ACF_Step5m.pl unmap.parsed.tmp circle_candidates_MEA circle_candidates_MuS circle_candidates_CBR ".$SPEC{"UNMAP_expr"}." $MAS";
print OUT $command,"\n";
print OUT "echo \"Step5 caliberate_the_expression_of_circles Finished\" \n\n\n";


print OUT "#Step6\n";
print OUT "echo \"Step6 generating_UCSC_Genome_Browser_files Started\" \n";
$command="perl ".$SPEC{"ACF_folder"}."/ACF_Step6.pl circle_candidates_MEA.refFlat circle_candidates_MEA.expr circle_candidates_MEA.bed12 circle_candidates_MEA $minSSSum $minSamplecnt $minReadcnt 0 0";
print OUT $command,"\n";
$command="perl ".$SPEC{"ACF_folder"}."/ACF_Step6.pl circle_candidates_CBR.refFlat circle_candidates_CBR.expr circle_candidates_CBR.bed12 circle_candidates_CBR $minSSSum $minSamplecnt $minReadcnt 0 0";
print OUT $command,"\n";
$command="perl ".$SPEC{"ACF_folder"}."/ACF_Step6.pl unmap.parsed.segs.S2 circle_candidates_MuS.expr circle_candidates_MuS.bed12 circle_candidates_MuS $minSSSum $minSamplecnt $minReadcnt 0 0";
print OUT $command,"\n";
print OUT "echo \"Step6 generating_UCSC_Genome_Browser_files Finished\" \n\n\n";

close OUT;
