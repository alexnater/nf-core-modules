process DELLY_CALL {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/delly:1.2.6--hb7e2ac5_1' :
        'biocontainers/delly:1.2.6--hb7e2ac5_1' }"

    input:
    tuple val(meta), path(input_1), path(input_1_idx), path(input_ctrl), path(input_ctrl_idx), path(vcf), path(vcf_index), path(exclude_bed)
    tuple val(meta2), path(fasta)
    tuple val(meta3), path(fai)

    output:
    tuple val(meta), path("*.{bcf,vcf.gz}"), emit: bcf
    tuple val(meta), path("*.{csi,tbi}")   , emit: csi
    path "versions.yml"                    , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def args2 = task.ext.args2 ?: ''
    def args3 = task.ext.args3 ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def suffix = task.ext.suffix ?: "bcf"

    def input = input_ctrl ? "${input_1} ${input_ctrl}" : "${input_1}"
    def exclude = exclude_bed ? "--exclude ${exclude_bed}" : ""

    def bcf_output = suffix == "bcf" ? "--outfile ${prefix}.bcf" : ""
    def vcf_output = suffix == "vcf" ? "| bgzip ${args2} --threads ${task.cpus} --stdout > ${prefix}.vcf.gz && tabix ${args3} ${prefix}.vcf.gz" : ""

    def genotype = vcf ? "--vcffile ${vcf}" : ""

    """
    delly \\
        call \\
        ${args} \\
        ${bcf_output} \\
        --genome ${fasta} \\
        ${genotype} \\
        ${exclude} \\
        ${input} \\
        ${vcf_output}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        delly: \$( echo \$(delly --version 2>&1) | sed 's/^.*Delly version: v//; s/ using.*\$//')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def suffix = task.ext.suffix ?: "bcf"

    def bcf_output = suffix == "bcf" ? "touch ${prefix}.bcf && touch ${prefix}.bcf.csi" : ""
    def vcf_output = suffix == "vcf" ? "echo '' | gzip > ${prefix}.vcf.gz && touch ${prefix}.vcf.gz.tbi" : ""

    """
    ${bcf_output}
    ${vcf_output}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        delly: \$( echo \$(delly --version 2>&1) | sed 's/^.*Delly version: v//; s/ using.*\$//')
    END_VERSIONS
    """
}
