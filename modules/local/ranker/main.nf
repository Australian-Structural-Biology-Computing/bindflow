process RANKER {
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.8.3' :
        'quay.io/biocontainers/python:3.8.3' }"

    input:
    tuple val(meta), path (stats, name: 'final_design_stats_?.csv')
    tuple val(meta), path (pdb, name: 'Ranked_?')
    
    output:
    tuple val(meta), path("${meta.id}_final_design_stats.csv"), emit: stats
    tuple val(meta), path("${meta.id}_Ranked"), emit: accepted_ranked
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    
    """
    #!/usr/bin/env python3
    import os
    import glob
    import csv
    import sys
    import shutil

    main_list = []
    column_order = None
    os.makedirs("${meta.id}_Ranked", exist_ok=True)
    def resolve_symlink(file_path):
        return os.path.realpath(file_path) if os.path.islink(file_path) else file_path
    
    csv_files = ["${stats.join('", "')}"]
    if len(csv_files) == 1:
        csv_file = csv_files[0]
        # Extract id and associated Ranked directory
        id_part = csv_file.split("_")[-1].replace(".csv", "")
        ranked_dir = f"Ranked_{id_part}"

        # Copy the CSV file as-is to the output location
        shutil.copy(resolve_symlink(csv_file), '${meta.id}_final_design_stats.csv')

        # Copy all files from the Ranked_id directory
        if os.path.isdir(ranked_dir):
            ranked_files = glob.glob(os.path.join(ranked_dir, "*.pdb"))
            for ranked_file in ranked_files:
                actual_file = resolve_symlink(ranked_file)
                shutil.copy(actual_file, os.path.join("${meta.id}_Ranked", os.path.basename(actual_file)))

        print(f"Single CSV detected. Copied CSV and all associated files to Ranked")
        
    else:
        for file_name in csv_files:
            print(f"loading file {file_name}...")
            # Extract the id from the filename
            id_part = file_name.split("_")[-1].replace(".csv", "")
            ranked_dir = f"Ranked_{id_part}"

            # Dictionary to store CSV data keyed by 'ranked'
            ranked_dict = {}

            # Read CSV file and store data
            with open(file_name, newline='', encoding='utf-8') as csvfile:
                reader = csv.DictReader(csvfile)
                if column_order is None:
                    column_order = reader.fieldnames
                for row in reader:
                    ranked_value = row["Rank"].strip()
                    if ranked_value:
                        ranked_dict[ranked_value] = row

            # If ranked directory exists, match files to the dictionary
            if os.path.isdir(ranked_dir):
                ranked_files = glob.glob(os.path.join(ranked_dir, "*.pdb"))

                for ranked_file in ranked_files:
                    print(f"found pdb file {ranked_file}")
                    ranked_filename = os.path.basename(ranked_file)
                    rank_key = ranked_filename.split("_")[0]  # Extract rank from file name

                    if rank_key in ranked_dict:
                        # Resolve symlink to actual file if applicable
                        ranked_dict[rank_key]["file_path"] = resolve_symlink(ranked_file)
            else:
                print("pdb directory does not exist!")
                exit(1)
            # Add processed entries to main list
            main_list.extend(ranked_dict.values())
            #print(main_list)
        
        main_list.sort(key=lambda x: float(x["Average_i_pTM"]), reverse=True)

        # Save the sorted data to a new CSV file (excluding file_path)
        if main_list and column_order:
            output_headers = [col for col in column_order if col != "file_path"]  # Maintain original order
            with open('${meta.id}_final_design_stats.csv', mode='w', newline='', encoding='utf-8') as csvfile:
                writer = csv.DictWriter(csvfile, fieldnames=output_headers)
                writer.writeheader()
                for new_rank, row in enumerate(main_list, start=1):
                    row["Rank"] = new_rank
                    writer.writerow({key: row[key] for key in output_headers})

        # Copy files to Ranked and rename based on new rank
        for new_rank, row in enumerate(main_list, start=1):
            original_path = row.get("file_path")
            print(new_rank, row["Average_i_pTM"], original_path)
            if original_path and os.path.exists(original_path):
                original_filename = os.path.basename(original_path)
                parts = original_filename.split("_", 1)  # Split at first underscore
                if len(parts) == 2:
                    new_filename = f"{new_rank}_{parts[1]}"  # Change rank in filename
                else:
                    new_filename = f"{new_rank}_{original_filename}"  # Fallback

                new_path = os.path.join("${meta.id}_Ranked", new_filename)
                shutil.copy(original_path, new_path)  # Copy with new name

    
    print(f"Processing complete. Sorted CSV saved to ${meta.id}_final_design_stats.csv")
    print(f"Files copied to ${meta.id}_Ranked with updated ranks.")

        
    with open ("versions.yml", "w") as version_file:
	    version_file.write("\\"${task.process}\\":\\n    python: {}\\n".format(sys.version.split()[0].strip()))
    """

    stub:
    """
    mkdir -p s1_Ranked
    touch s1_final_design_stats.csv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
    END_VERSIONS
    """
}
