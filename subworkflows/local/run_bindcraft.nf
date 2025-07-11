//
// Subworkflow with functionality specific to the ziadbkh/bindflow pipeline
//

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { JSONMANAGER               } from '../../modules/local/jsonmanager'
include { samplesheetToList         } from 'plugin/nf-schema'
include { BINDCRAFT                 } from '../../modules/local/bindcraft'
include { RANKER                 } from '../../modules/local/ranker'
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUBWORKFLOW TO INITIALISE PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow RUN_BINDCRAFT {

    take:
    input             //  string: Path to input samplesheet
    batches           //  integer: the number of batches to divid the final number of designs on to run bindcraft in parallel
    quote_char
    main:

    ch_versions = Channel.empty()
    
    input
    .splitCsv(header: true, quote : quote_char)
    .map {row ->
       [
            ["id": row.id], 
            file(row.starting_pdb, checkIfExists: true),
            get_file(row.settings_filters, params.settings_filters, "${projectDir}/assets/bindcraft/default_filters.json"),
            get_file(row.settings_advanced, params.settings_advanced, "${projectDir}/assets/bindcraft/default_4stage_multimer.json"),    
       ]
    }
    .set { ch_settings }
    input
    .splitCsv(header: true, quote : quote_char)
    .map {row ->
       [
            ["id": row.id],
            row.number_of_final_designs
       ] 
    }.set{ch_final_designs}

    JSONMANAGER(
        input,
        batches
    )

    JSONMANAGER.out.json
        .flatten()
        .map{[["id": it.baseName.split('-')[0..-2].join('-')], it.baseName.split('-')[-1].replace(".json", ""), it]}
        .combine(ch_settings)
        .filter{it[0].id == it[3].id}
        .map{[["id": it[0].id, "batch": it[1]], it[2], it[4], it[5], it[6]]}
        .set {ch_bindcraft_input}
    
    BINDCRAFT(
        ch_bindcraft_input.map {[it[0], it[1]]},
        ch_bindcraft_input.map {it[2]},
        ch_bindcraft_input.map {it[3]},
        ch_bindcraft_input.map {it[4]}
    )

    BINDCRAFT.out.accepted
        .map{[["id": it[0].id], it[1]]}
        .groupTuple()
        .join(ch_final_designs)
        .subscribe{
            if (it[1].size() < it[2]){
                log.warn "Sample: ${it[0].id}: The pipeline was unable to generate the target number of successful designs (${it[1].size()} of ${it[2]}) in the allocated time. Please consider changing hotspot residues or design configuration to increase design success rates"
            }
        } 

    RANKER(
        BINDCRAFT.out.stats.map{[["id": it[0].id], it[1]]}.groupTuple(),
        BINDCRAFT.out.accepted_ranked.map{[["id": it[0].id], it[1]]}.groupTuple()
    )
    
    emit:
    input_json  = JSONMANAGER.out.json
                    .flatten()
                    .map{[it.baseName.split('-')[0..-2].join('-'), 
                          it.baseName.split('-')[-1].replace(".json", ""), 
                          it]
                    }
    output_dir  = BINDCRAFT.out.output_dir
    stats       = RANKER.out.stats
    ranked      = RANKER.out.accepted_ranked
    versions    = ch_versions
}

def get_file(String sheet_file, String general_file, String assets_file) {
    if (!sheet_file || sheet_file.trim().isEmpty()) {
        return general_file ? file(general_file) : file(assets_file)
    }
    
    if (!file(sheet_file).exists()) {
        exit 1, "ERROR: Please check input samplesheet -> file does not exist!\n${sheet_file}"
    }

    return file(sheet_file)
}