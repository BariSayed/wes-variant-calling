#!/usr/bin/env bash
# =============================================================================
# Whole Exome Sequencing (WES) / Variant-Calling Pipeline
# -----------------------------------------------------------------------------
# A reproducible short-read variant-calling workflow demonstrated on a public
# E. coli paired-end Illumina dataset (NCBI SRA: SRR27293200).
#
# Workflow:  QC  ->  trimming  ->  alignment  ->  sort/index  ->  variant calling
# Tools:     FastQC, Trimmomatic, Bowtie2, SAMtools, BCFtools
#
# Completed as a training assignment (see README.md for attribution).
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# 0. Environment setup
# -----------------------------------------------------------------------------
# conda create -n wes_env python=3.10 -y
# conda activate wes_env
#
# conda config --add channels defaults
# conda config --add channels bioconda
# conda config --add channels conda-forge
#
# conda install -y \
#     sra-tools fastqc multiqc trimmomatic cutadapt \
#     bowtie2 bwa samtools sambamba picard \
#     gatk4 bedtools bcftools freebayes \
#     snpeff ensembl-vep htslib vcftools tabix \
#     pandas matplotlib seaborn openjdk=11

SRA="SRR27293200"
THREADS=4
REF="ecoli.fasta"

# -----------------------------------------------------------------------------
# 1. Download the public sequencing reads (SRA)
# -----------------------------------------------------------------------------
prefetch "${SRA}"
fasterq-dump "${SRA}" --split-files --threads ${THREADS}
# -> produces ${SRA}_1.fastq and ${SRA}_2.fastq

# -----------------------------------------------------------------------------
# 2. Download the E. coli reference genome
# -----------------------------------------------------------------------------
# Example: E. coli K-12 MG1655 (RefSeq GCF_000005845.2). Adjust to the
# reference used in your assignment.
# datasets download genome accession GCF_000005845.2 --include genome
# unzip ncbi_dataset.zip && mv ncbi_dataset/data/GCF_000005845.2/*.fna "${REF}"

# -----------------------------------------------------------------------------
# 3. Quality control (FastQC)
# -----------------------------------------------------------------------------
mkdir -p fastqc_reports
fastqc "${SRA}_1.fastq" "${SRA}_2.fastq" -o fastqc_reports
# multiqc fastqc_reports -o fastqc_reports   # optional aggregated report

# -----------------------------------------------------------------------------
# 4. Adapter/quality trimming (Trimmomatic)
# -----------------------------------------------------------------------------
# Parameters:
#   PE                       paired-end mode
#   ILLUMINACLIP             remove TruSeq3-PE adapters (mismatch:palindrome:simple = 2:30:10)
#   LEADING:3 / TRAILING:3   trim leading/trailing bases with quality < 3
#   SLIDINGWINDOW:4:15       trim once mean quality in a 4-base window drops below 15
#   MINLEN:36                drop reads shorter than 36 bp after trimming
mkdir -p trimmed_reads
trimmomatic PE -threads ${THREADS} \
  "${SRA}_1.fastq" "${SRA}_2.fastq" \
  trimmed_reads/${SRA}_1_paired.fq.gz trimmed_reads/${SRA}_1_unpaired.fq.gz \
  trimmed_reads/${SRA}_2_paired.fq.gz trimmed_reads/${SRA}_2_unpaired.fq.gz \
  ILLUMINACLIP:TruSeq3-PE.fa:2:30:10 \
  LEADING:3 TRAILING:3 SLIDINGWINDOW:4:15 MINLEN:36

# -----------------------------------------------------------------------------
# 5. Build the reference index and align (Bowtie2)
# -----------------------------------------------------------------------------
bowtie2 --version
bowtie2-build "${REF}" ecoli_index
# generates ecoli_index.{1,2,3,4}.bt2 and ecoli_index.rev.{1,2}.bt2

bowtie2 -x ecoli_index \
  -1 trimmed_reads/${SRA}_1_paired.fq.gz \
  -2 trimmed_reads/${SRA}_2_paired.fq.gz \
  --very-sensitive \
  -p ${THREADS} \
  -S alignment.sam

# -----------------------------------------------------------------------------
# 6. SAM -> sorted, indexed BAM (SAMtools)
# -----------------------------------------------------------------------------
samtools view -Sb alignment.sam > alignment.bam
samtools sort alignment.bam -o alignment.sorted.bam
samtools index alignment.sorted.bam

# -----------------------------------------------------------------------------
# 7. Variant calling (BCFtools; haploid genome -> --ploidy 1)
# -----------------------------------------------------------------------------
samtools faidx "${REF}"
bcftools mpileup -Ou -f "${REF}" alignment.sorted.bam \
  | bcftools call -mv --ploidy 1 -Ov -o variants.vcf

# Optional alternative caller:
# freebayes -f "${REF}" -p 1 alignment.sorted.bam > variants.freebayes.vcf

echo "Pipeline complete. Variants written to variants.vcf"
