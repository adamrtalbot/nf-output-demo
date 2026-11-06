# Nextflow output patterns

An example repository comparing three ways to get results out of a Nextflow pipeline:

1. `publishDir`
2. `publishDir` with data lineage
3. Workflow outputs (`output {}` block) with an index

All three run the same toy pipeline: three samples with `patient` and `tissue` metadata, two processes (`COUNT`, `GC`), and identical output filenames (`s1.count.txt`, `s1.gc.txt`, ...). The only thing that changes is whether anything besides the filename links each file to its sample.

The short version: the workflow output syntax is the only one of the three where Nextflow itself writes down which sample each file belongs to. With the other two, you rebuild that link after the run.

| | Pattern | What links a file to its sample |
|-|-|-|
| 1 | `publishDir` | Only the filename |
| 2 | `publishDir` + lineage | A provenance graph you walk back to each task's inputs |
| 3 | Records + `output {}` block | An index (CSV/JSON) with one row per sample |

If you're writing a new pipeline, use records and the `output {}` block.

Tested with Nextflow 26.10.2. Pattern 3 uses static types and record types, so it needs a recent Nextflow release.

## 1. publishDir

```bash
cd 1-publishdir && nextflow run main.nf
find results -type f
```

```
results/count/s1.count.txt
results/count/s2.count.txt
results/count/s3.count.txt
results/gc/s1.gc.txt
...
```

Inside the pipeline, each file travels with a `meta` map (`id`, `patient`, `tissue`). `publishDir` copies the file and drops the map. You can guess that `s1.count.txt` belongs to sample `s1` from the naming convention, but nothing on disk records it, and nothing records that `s1` is patient `P01` or tumour tissue. To load these files into a data lake or trigger automation, you list the folder, parse filenames and rejoin them to the samplesheet. That breaks as soon as a process names its outputs differently.

## 2. Lineage

Same `main.nf`, plus `lineage.enabled = true` in `nextflow.config`.

```bash
cd 2-lineage && nextflow run main.nf
python3 resolve.py
```

```
id,patient,tissue,process,path
s1,P01,tumour,COUNT (1),.../results/count/s1.count.txt
s1,P01,tumour,GC (1),.../results/gc/s1.gc.txt
...
```

`resolve.py` ignores filenames. For each published file it walks three hops: published file → `source` task output → `TaskRun` → the `meta` input. Lineage works on any existing pipeline without code changes, so it makes a good bridge. The cost lands on the consumer: you need to know the shape of the lineage records and the name of each pipeline's meta input, and you run several `nextflow lineage view` calls per file.

## 3. Workflow outputs with an index

`main.nf` uses typed `params`, `record` types and an `output {}` block. The metadata stays attached to the files through the channel, and Nextflow writes it out as an index next to the files.

```bash
cd 3-workflow-outputs && nextflow run main.nf
cat results/results.csv
```

```
id,patient,tissue,fasta,count,gc
s1,P01,tumour,.../data/s1.fa,.../results/s1.count.txt,.../results/s1.gc.txt
...
```

The index is a table, so you can load it with one command:

```bash
sqlite3 results.db ".import --csv results/results.csv samples" \
  "SELECT patient, id, gc FROM samples WHERE tissue='tumour'"
```

The files match pattern 1, but nothing downstream parses their names. Change the output names inside the pipeline and the index still says which sample each file belongs to.

## Why the output syntax is better

- **The pipeline author records the link once.** With patterns 1 and 2, every consumer of the results has to reconstruct it.
- **Downstream tools need no Nextflow knowledge.** A SQL load, an HTTP POST or a data lake ingest reads a CSV or JSON file. Nobody has to parse filenames or query the lineage store.
- **Output becomes a contract.** The `output {}` block declares what the pipeline publishes and its type (`Channel<Result>`), so changes to the outputs show up in code review.

If you're writing a pipeline now, use records and the `output {}` block from the start. For an existing pipeline, move to them as part of a migration to the Nextflow 26.04 standard (strict syntax, static types, records). Until then, lineage can recover the metadata from existing runs.
