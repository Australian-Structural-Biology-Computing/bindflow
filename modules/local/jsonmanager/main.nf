process JSONMANAGER {
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.8.3' :
        'quay.io/biocontainers/python:3.8.3' }"

    input:
    path samplesheet
    val batches

    output:
    path "*.json"      , emit: json
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def quote_char = task.ext.args2 ?: "\""
    """
    #!/usr/bin/env python3
    import csv
    import json
    import os, sys
    import math

    with open("${samplesheet}", 'r') as csvfile:
        reader = csv.DictReader(csvfile, quotechar="\\${quote_char}")
        for row in reader:
            batches = ${batches}
            if batches < 1:
                batches = 1
            sample_id = row['id']
            if 'starting_pdb' in row:
                row['starting_pdb_path'] = row['starting_pdb']
                row['starting_pdb'] = os.path.basename(row['starting_pdb'])
            row['lengths'] = [int(row['min_length']), int(row['max_length'])]
            number_of_final_designs = int(row['number_of_final_designs'])
            if batches > number_of_final_designs:
                batches = number_of_final_designs
            
            batch_size = math.ceil(number_of_final_designs / batches)
            row['number_of_final_designs'] = batch_size
            for batch_id in range(0, batches):
                if batch_id == batches - 1:
                    row['number_of_final_designs'] = number_of_final_designs - batch_id * batch_size
                row['design_path'] = f"{sample_id}_{batch_id}_output"
                with open(f"{sample_id}-{batch_id}.json", 'w') as jsonfile:
                    json.dump(row, jsonfile, indent=2)
        
    with open ("versions.yml", "w") as version_file:
	    version_file.write("\\"${task.process}\\":\\n    python: {}\\n".format(sys.version.split()[0].strip()))
    """

    stub:
    """
    touch s1-0.json
    touch s1-1.json

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
    END_VERSIONS
    """
}
