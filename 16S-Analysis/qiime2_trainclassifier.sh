#!/bin/bash
#SBATCH --mem=200000
#SBATCH --tasks-per-node=8
#SBATCH --time=7-0:0:0
#SBATCH --mail-user="rstevick@uri.edu"
#SBATCH --mail-type=END,FAIL
#SBATCH --output="slurm-%x-%j.out"

echo "QIIME2 classifier training started at : "; date

cd /data/marine_diseases_lab/rebecca/PJsequencing/amplicons16S/db

module purge
module load QIIME2/2023.5
module list

# full length classifier is silva-138-99-nb-classifier.qza
# this script is to make a V6-specific classifier with Silva 138 - 99 data

qiime feature-classifier extract-reads \
  --i-sequences silva-138-99-seqs.qza \
  --p-f-primer CTAACCGANGAACCTYACC \
  --p-r-primer CGACRRCCATGCANCACCT \
  --p-min-length 40 \
  --p-max-length 150 \
  --o-reads ref-seqs-V6.qza

qiime feature-classifier fit-classifier-naive-bayes \
  --i-reference-reads ref-seqs-V6.qza \
  --i-reference-taxonomy silva-138-99-tax.qza \
  --o-classifier classifier-V6-silva-138-99.qza

echo "END $(date)"
