// Pattern 3: typed records + workflow outputs. Metadata travels with the files and is written to an index.
nextflow.enable.types = true

params {
    input: Path = "${projectDir}/../data/samples.csv"
}

record Sample {
    id: String
    patient: String
    tissue: String
    fasta: Path
}

record Result {
    id: String
    patient: String
    tissue: String
    count: Path
    gc: Path
}

process COUNT {
    input:
    s: Sample

    output:
    record(id: s.id, count: file("${s.id}.count.txt"))

    script:
    """
    grep -c '>' ${s.fasta} > ${s.id}.count.txt
    """
}

process GC {
    input:
    s: Sample

    output:
    record(id: s.id, gc: file("${s.id}.gc.txt"))

    script:
    """
    grep -v '>' ${s.fasta} | tr -cd 'GC' | wc -c > ${s.id}.gc.txt
    """
}

workflow {
    main:
    samples = channel.fromList(params.input.splitCsv(header: true))
        .map { row -> record(id: row.id, patient: row.patient, tissue: row.tissue, fasta: file("${projectDir}/../${row.fasta}")) }

    results = samples
        .join(COUNT(samples), by: 'id')
        .join(GC(samples), by: 'id')

    publish:
    results = results
}

output {
    results: Channel<Result> {
        index {
            path 'results.csv'
            header true
        }
    }
}
