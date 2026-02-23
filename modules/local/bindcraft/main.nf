process BINDCRAFT {
    label 'process_long'

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
    def gpuCount = (params.gpu_device_count ?: 1) as Integer
    def gpuId = ((task.index ?: 1) - 1) % gpuCount
    
    """
    export CUDA_VISIBLE_DEVICES=${gpuId}
    export XLA_PYTHON_CLIENT_PREALLOCATE=false
    export XLA_PYTHON_CLIENT_ALLOCATOR=platform
    export XLA_PYTHON_CLIENT_MEM_FRACTION=0.60
    export TF_FORCE_GPU_ALLOW_GROWTH=true
    echo "BINDCRAFT task ${task.index ?: 1} using CUDA_VISIBLE_DEVICES=\$CUDA_VISIBLE_DEVICES"

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
    def version = "1.2.0"
    """
    mkdir -p s1_1_output/Accepted/Ranked
    touch s1_1_output/Accepted/accepted1.pdb
    touch s1_1_output/Accepted/Ranked/ranked1.pdb
    touch s1_1_final_design_stats.csv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bindcraft: $version
    END_VERSIONS
    """
}
