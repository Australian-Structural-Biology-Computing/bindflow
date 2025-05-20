process BINDCRAFT {
    label 'process_long'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'australianbiocommons/bindcraft:1.2.0' :
        'australianbiocommons/bindcraft:1.2.0' }"

    input:
    tuple val(meta), path (target_file)
    path (pdb)
    path (filters)
    path (advanced_settings)
    
    output:
    tuple val(meta), path("*_final_design_stats.csv"), emit: stats
    tuple val(meta), path("*_output/Accepted/Ranked"), emit: accepted_ranked
    tuple val(meta), path("*_output/Accepted/*pdb"), emit: accepted
    tuple val(meta), path("*_output"), emit: output_dir
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def version = "1.2.0"
    def args = task.ext.args ?: ''
    
    """
    /app/run_bindcraft.sh \\
        --settings ${target_file} \\
        --filters ${filters} \\
        --advanced ${advanced_settings} \\
        $args \\
    
    cp *_output/final_design_stats.csv ${meta.id}_${meta.batch}_final_design_stats.csv 

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bindcraft: $version
    END_VERSIONS
    """

    stub:
    """
    mkdir -p s1_1_output/Accepted/Ranked
    touch s1_1_output/Accepted/Ranked/ranked1.pdb
    touch s1_output/s1_1_final_design_stats.csv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bindcraft: $version
    END_VERSIONS
    """
}
