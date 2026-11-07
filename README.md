# Whole Exome Sequencing (WES) / Variant-Calling Pipeline

A reproducible short-read **variant-calling workflow** demonstrated on a public
*E. coli* paired-end Illumina dataset (NCBI SRA accession **SRR27293200**).

This repository was created as a **completed training assignment** (see
*Attribution* below). The pipeline uses only open-source bioinformatics tools and
publicly available sequencing data.

---

## Workflow overview

```
FASTQ reads (SRA)
      │
      ▼
[1] Quality control        FastQC / MultiQC
      │
      ▼
[2] Adapter & quality trim Trimmomatic
      │
      ▼
[3] Alignment to reference Bowtie2
      │
      ▼
[4] SAM → sorted BAM       SAMtools
      │
      ▼
[5] Variant calling        BCFtools (ploidy = 1)
      │
      ▼
   variants.vcf
```

## Dataset

| Item          | Value                                                        |
|---------------|--------------------------------------------------------------|
| Organism      | *Escherichia coli*                                           |
| Data type     | Paired-end Illumina short reads (WES-style exercise)         |
| SRA accession | [SRR27293200](https://www.ncbi.nlm.nih.gov/sra/?term=SRR27293200) |
| Reference     | *E. coli* K-12 MG1655 (RefSeq GCF_000005845.2) — adjust as used |

> The reads are downloaded directly from the public NCBI SRA, so the workflow is
> fully reproducible by anyone.

## Requirements

Create the environment with conda (Bioconda):

```bash
conda create -n wes_env python=3.10 -y
conda activate wes_env
conda config --add channels defaults
conda config --add channels bioconda
conda config --add channels conda-forge

conda install -y \
    sra-tools fastqc multiqc trimmomatic cutadapt \
    bowtie2 bwa samtools sambamba picard \
    gatk4 bedtools bcftools freebayes \
    snpeff ensembl-vep htslib vcftools tabix \
    pandas matplotlib seaborn openjdk=11
```

## Usage

```bash
chmod +x wes_pipeline.sh
./wes_pipeline.sh
```

Each step is documented inline in [`wes_pipeline.sh`](wes_pipeline.sh). Run the
steps interactively first if you want to inspect intermediate outputs
(`fastqc_reports/`, `trimmed_reads/`, `alignment.sorted.bam`, `variants.vcf`).

## Pipeline steps

1. **Download reads** — `prefetch` + `fasterq-dump` fetch SRR27293200 as paired FASTQ.
2. **Quality control** — `fastqc` on both mates (optionally aggregated with `multiqc`).
3. **Trimming** — `trimmomatic PE` removes TruSeq3 adapters and low-quality bases.
4. **Alignment** — `bowtie2 --very-sensitive` against the indexed reference.
5. **BAM processing** — `samtools view | sort | index`.
6. **Variant calling** — `bcftools mpileup | call -mv --ploidy 1` → `variants.vcf`
   (ploidy 1 because the bacterial genome is haploid).

## Notes & learning points

- `--ploidy 1` is used because *E. coli* is haploid; for diploid organisms omit it.
- `bwa` is also installed as an alternative aligner commonly used in human WES
  (`bwa mem`); this exercise uses Bowtie2.
- Large intermediate files (FASTQ, SAM, BAM, VCF, indices) are **not** committed —
  see [`.gitignore`](.gitignore). They regenerate by re-running the pipeline.

## Attribution

> **Please update the bracketed fields below before sharing widely.**

This work was completed as a hands-on assignment during a bioinformatics training
on Whole Exome Sequencing / variant calling:

- **Training / workshop:** _[training or workshop name]_
- **Conducted by / instructor:** _[instructor or organizing institution]_
- **Date:** _[month, year]_

The pipeline design and tool choices follow what was taught during the training.
The code in this repository is my own implementation of the assigned exercise.
All datasets used are publicly available; no proprietary course material is
redistributed here.

## License

Code in this repository is released under the [MIT License](LICENSE).
The underlying bioinformatics tools and the SRA dataset retain their own
respective licenses and terms of use.
