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

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUBWORKFLOW TO INITIALISE PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow RUN_BINDCRAFT {

    take:
    input             //  string: Path to input samplesheet

    main:

    ch_versions = Channel.empty()

    input
    .splitCsv(header: true)
    .map {row ->
       [
            row.id, 
            file(row.starting_pdb, checkIfExists: true),
            get_file(row.settings_filters, params.settings_filters, "${projectDir}/assets/bindcraft/default_filters.json"),
            get_file(row.settings_advanced, params.settings_advanced, "${projectDir}/assets/bindcraft/default_4stage_multimer.json"),    
       ]
    }
    .set { ch_settings }
    
    JSONMANAGER(
        input
    )
    
    JSONMANAGER.out.json
        .flatten()
        .map{[it.baseName, it]}
        .join(ch_settings)
        .set {ch_bindcraft_input}
    
    BINDCRAFT(
        ch_bindcraft_input.map {[["id": it[0]], it[1]]},
        ch_bindcraft_input.map {it[2]},
        ch_bindcraft_input.map {it[3]},
        ch_bindcraft_input.map {it[4]}
    )
        
    

    emit:
    //samplesheet = ch_samplesheet
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