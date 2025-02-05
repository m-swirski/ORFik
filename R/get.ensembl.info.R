#' @title Helper function to retrieve species information from the ENSEMBL API
#' @description This function interfaces with the ENSEMBL API
#' (https://rest.ensembl.org/info/species?content-type=application/json)
#' and internally stores the output to use this information for subsequent
#' retrieval function calls.
#' @param update logical, default FALSE. If TRUE, force re-download of info
#' @inheritParams ensembl_rest_url_species
#' @author Hajk-Georg Drost
#' @noRd
get.ensembl.info <- function(update = FALSE, division = "EnsemblVertebrates") {
  tmp_file <- file.path(tempdir(), paste0(division, "_info.tsv"))
  if (file.exists(tmp_file) &&
        !update) {
        suppressWarnings(
            ensembl.info <-
                readr::read_tsv(
                    tmp_file,
                    col_names = TRUE,
                    col_types = readr::cols(
                        division = readr::col_character(),
                        taxon_id = readr::col_integer(),
                        name = readr::col_character(),
                        release = readr::col_integer(),
                        display_name = readr::col_character(),
                        accession = readr::col_character(),
                        common_name = readr::col_character(),
                        assembly = readr::col_character()
                    )
                )
        )

    } else {


        rest_url <- ensembl_rest_url_species_division(division)
        rest_api_status <- curl::curl_fetch_memory(rest_url)
        if (rest_api_status$status_code != 200) {
            message(
                "The API 'https://rest.ensembl.org' does not seem to
                respond or work properly. Is the homepage 'https://rest.ensembl.org' currently available?",
                " Could it be that there is a firewall issue on your side? Please re-run the function and check if it works now."
            )
        }

            ensembl.info <-
                tibble::as_tibble(
                    jsonlite::fromJSON(
                        rest_url
                    )$species
                )

        aliases <- groups <- NULL
        ensembl.info <-
            dplyr::select(ensembl.info, -aliases, -groups)

        readr::write_tsv(ensembl.info, tmp_file)
    }

    return(ensembl.info)
}

ensembl_rest_url <- function() {
  "https://rest.ensembl.org"
}

ensembl_divisions <- function() {
  c("EnsemblVertebrates", "EnsemblPlants", "EnsemblFungi", "EnsemblMetazoa",
    "EnsemblBacteria")
}
ensembl_divisions_short <- function() {
  c(EnsemblVertebrates = "", EnsemblPlants = "plants", EnsemblFungi = "fungi",
    EnsemblBacteria = "bacteria", EnsemblMetazoa = "metazoa")
}

ensembl_rest_url_species <- function() {
  file.path(ensembl_rest_url(), "info/species")
}


#' Get supported species from given division
#'
#' @param division "EnsemblVertebrates", alternatives:
#'  "EnsemblPlants", "EnsemblFungi", "EnsemblMetazoa", "EnsemblBacteria"
#' @noRd
ensembl_rest_url_species_division <- function(division = "EnsemblVertebrates") {
  stopifnot(division %in% ensembl_divisions())
  suffix_url <- paste0("?division=", division,
                       "&content-type=application/json")
  file.path(ensembl_rest_url_species(), suffix_url)
}

ensembl_current_release <- function(division = "EnsemblVertebrates") {
  if (division == "EnsemblVertebrates") {
    jsonlite::fromJSON(
      file.path(ensembl_rest_url(), "info/data/?content-type=application/json")
    )$releases
  } else {
    jsonlite::fromJSON(
      file.path(ensembl_rest_url(),
                "info/eg_version?content-type=application/json"))$version
  }
}

ensembl_all_releases <- function(division = "EnsemblVertebrates") {
  seq_len(as.integer(ensembl_current_release(division)))
}

ensembl_rest_url_assembly <- function(organism) {
  file.path(ensembl_rest_url(),
            paste0("info/assembly/", organism,
                   "?content-type=application/json"
  ))
}

ensembl_ftp_server_url <- function(division) {
  if (division == "EnsemblVertebrates") {
    "ftp://ftp.ensembl.org"
  } else {
    "ftp://ftp.ensemblgenomes.org"
  }
}

ensembl_ftp_server_url_release_style <- function(division, release = NULL) {
  if (division == "EnsemblVertebrates") {
    if (is.null(release)) {
      "pub/current_fasta/"
    } else paste0("pub/release-", release ,"/fasta/")

  } else {ensembl_divisions
    short_name <- ensembl_divisions_short()[division]
    if (is.null(release)) {
      paste0("pub/current/", short_name, "/fasta/")
    } else paste0("pub/release-", release ,"/", short_name, "/fasta/")
  }
}

ensembl_ftp_server_url_release_style_gtf <- function(division, release = NULL) {
  if (division == "EnsemblVertebrates") {
    if (is.null(release)) {
      "pub/current_gtf/"
    } else paste0("pub/release-", release ,"/gtf/")

  } else {ensembl_divisions
    short_name <- ensembl_divisions_short()[division]
    if (is.null(release)) {
      paste0("pub/current/", short_name, "/gtf/")
    } else paste0("pub/release-", release ,"/", short_name, "/gtf/")
  }
}

ensembl_ftp_server_url_fasta <- function(division, release = NULL) {
  file.path(ensembl_ftp_server_url(division),
            ensembl_ftp_server_url_release_style(division, release))
}

ensembl_ftp_server_url_gtf <- function(division, release = NULL) {
  file.path(ensembl_ftp_server_url(division),
            ensembl_ftp_server_url_release_style_gtf(division, release))
}

ensembl_ftp_server_query_full <- function(core_path, new.organism, type,
                                          assembly_option, id.type,
                                          ensembl_summary) {
  collection_for_bacteria_only <- get_bacteria_collection_id(ensembl_summary)
  if (isFALSE(collection_for_bacteria_only)) return(FALSE)
  paste0(
    core_path,
    collection_for_bacteria_only,
    stringr::str_to_lower(new.organism),
    "/",
    type,
    "/",
    ensembl_seq_file_base(new.organism, assembly_option, type,
                          id.type)
  )
}
