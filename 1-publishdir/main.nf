// Pattern 1: publishDir. Files land in a folder; their metadata (patient, tissue) stays behind.
params.input = "${projectDir}/../data/samples.csv"
params.outdir = 'results'

process COUNT {
    publishDir "${params.outdir}/count", mode: 'copy'

    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path("${meta.id}.count.txt")

    script:
    """
    grep -c '>' ${fasta} > ${meta.id}.count.txt
    """
}

process GC {
    publishDir "${params.outdir}/gc", mode: 'copy'

    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path("${meta.id}.gc.txt")

    script:
    """
    grep -v '>' ${fasta} | tr -cd 'GC' | wc -c > ${meta.id}.gc.txt
    """
}

workflow {
    samples = channel.fromPath(params.input)
        .splitCsv(header: true)
        .map { row -> tuple(row.subMap('id', 'patient', 'tissue'), file("${projectDir}/../${row.fasta}")) }

    COUNT(samples)
    GC(samples)
}
