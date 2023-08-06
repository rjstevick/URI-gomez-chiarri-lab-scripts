#!/bin/bash
#SBATCH --mem=200000
#SBATCH --tasks-per-node=8
#SBATCH --time=7-0:0:0
#SBATCH --mail-user="rstevick@uri.edu"
#SBATCH --mail-type=END,FAIL
#SBATCH --output="slurm-%x-%j.out"

# This script performs the QIIME2 16S rRNA gene amplicon analysis pipeline
# Updated for QIIME2 v2023.5

echo "QIIME2 bash script for samples started running at: "; date

module purge
module load QIIME2/2023.5
module list

################################################
#### Edit here

# go to working directory
cd /data/marine_diseases_lab/XXXXXXXXXXX

# Put metadata file names here
METADATA="Metadata.txt"
MANIFEST="sample-manifest.txt"
CLASSIFIERV6="amplicons16S/db/classifier-V6-silva-138-99.qza"

################################################


# Import data into QIIME - Paired-end, based on sample-manifest_PJ_V6
qiime tools import --type 'SampleData[PairedEndSequencesWithQuality]' \
  --input-path $MANIFEST \
  --output-path paired-end-sequences.qza \
  --input-format PairedEndFastqManifestPhred33V2

# QC using dada2
qiime dada2 denoise-paired --verbose --i-demultiplexed-seqs paired-end-sequences.qza \
  --p-trunc-len-r 75 --p-trunc-len-f 75 \
  --p-trim-left-r 19 --p-trim-left-f 19 \
  --o-table table.qza \
  --o-representative-sequences rep-seqs.qza \
  --o-denoising-stats denoising-stats.qza \
  --p-n-reads-learn 1000000000 \
  --p-n-threads 8

# Summarize feature table and sequences
qiime metadata tabulate \
  --m-input-file denoising-stats.qza \
  --o-visualization denoising-stats.qzv
qiime feature-table summarize \
  --i-table table.qza \
  --o-visualization table.qzv \
  --m-sample-metadata-file $METADATA
qiime feature-table tabulate-seqs \
  --i-data rep-seqs.qza \
  --o-visualization rep-seqs.qzv

# Assign taxonomy based on the trained classifer
qiime feature-classifier classify-sklearn \
  --i-classifier $CLASSIFIERV6 \
  --i-reads rep-seqs.qza \
  --o-classification taxonomy.qza
qiime metadata tabulate \
  --m-input-file taxonomy.qza \
  --o-visualization taxonomy.qzv
qiime taxa barplot \
  --i-table table.qza \
  --i-taxonomy taxonomy.qza \
  --m-metadata-file $METADATA \
  --o-visualization taxa-bar-plots.qzv

# Assign taxonomy based on the full-length classifer
qiime feature-classifier classify-sklearn \
    --i-classifier $CLASSIFIERfull \
    --i-reads rep-seqs.qza \
    --o-classification taxafulldb/taxonomy.qza
qiime metadata tabulate \
    --m-input-file taxafulldb/taxonomy.qza \
    --o-visualization taxafulldb/taxonomy.qzv
qiime taxa barplot \
    --i-table table.qza \
    --i-taxonomy taxafulldb/taxonomy.qza \
    --m-metadata-file $METADATA \
    --o-visualization taxafulldb/taxa-bar-plots.qzv

# Calculate phylogenetic trees for the data
# align sequences
qiime alignment mafft \
  --i-sequences rep-seqs.qza \
  --o-alignment aligned-rep-seqs.qza
# mask sequences
qiime alignment mask \
  --i-alignment aligned-rep-seqs.qza \
  --o-masked-alignment masked-aligned-rep-seqs.qza
# calculate tree
qiime phylogeny fasttree \
  --i-alignment masked-aligned-rep-seqs.qza \
  --o-tree unrooted-tree.qza
qiime phylogeny midpoint-root \
  --i-tree unrooted-tree.qza \
  --o-rooted-tree rooted-tree.qza

# Calculate overall diversity metrics
qiime diversity core-metrics-phylogenetic \
  --i-phylogeny rooted-tree.qza \
  --i-table table.qza \
  --p-sampling-depth 95 \
  --m-metadata-file $METADATA \
  --output-dir core-metrics-results

# Alpha diversity
qiime diversity alpha-group-significance \
  --i-alpha-diversity core-metrics-results/faith_pd_vector.qza \
  --m-metadata-file $METADATA \
  --o-visualization core-metrics-results/faith-pd-group-significance.qzv
qiime diversity alpha-group-significance \
  --i-alpha-diversity core-metrics-results/evenness_vector.qza \
  --m-metadata-file $METADATA \
  --o-visualization core-metrics-results/evenness-group-significance.qzv

# Beta diversity
qiime diversity beta-group-significance \
  --i-distance-matrix core-metrics-results/unweighted_unifrac_distance_matrix.qza \
  --m-metadata-file $METADATA \
  --m-metadata-column TypeGroup \
  --o-visualization core-metrics-results/unweighted-unifrac-station-significance.qzv \
  --p-pairwise

# Rarefaction curve for the data
qiime diversity alpha-rarefaction \
  --i-table table.qza \
  --i-phylogeny rooted-tree.qza \
  --m-metadata-file $METADATA \
  --o-visualization alpha-rarefaction.qzv

echo "END $(date)"
