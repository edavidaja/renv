
#' Rebuild the Packages in your Project Library
#'
#' Rebuild and reinstall packages in your library. This can be useful as a
#' diagnostic tool -- for example, if you find that one or more of your
#' packages fail to load, and you want to ensure that you are starting from a
#' clean slate.
#'
#' @inherit renv-params
#'
#' @param packages The package(s) to be rebuilt. When `NULL`, all packages
#'   in the library will be reinstalled.
#'
#' @param recursive Boolean; should dependencies of packages be rebuilt
#'   recursively? Defaults to `TRUE`.
#'
#' @return A named list of package records which were installed by `renv`.
#'
#' @export
#'
#' @examples
#' \dontrun{
#'
#' # rebuild the 'dplyr' package + all of its dependencies
#' renv::rebuild("dplyr", recursive = TRUE)
#'
#' # rebuild only 'dplyr'
#' renv::rebuild("dplyr", recursive = FALSE)
#'
#' }
rebuild <- function(packages  = NULL,
                    recursive = TRUE,
                    ...,
                    type    = NULL,
                    prompt  = interactive(),
                    library = NULL,
                    project = NULL)
{
  renv_consent_check()
  renv_scope_error_handler()
  renv_dots_check(...)

  project <- renv_project_resolve(project)
  renv_scope_lock(project = project)

  libpaths <- renv_libpaths_resolve(library)
  library <- nth(libpaths, 1L)

  # get collection of packages currently installed
  records <- renv_snapshot_r_packages(libpaths = libpaths, project = project)
  if (empty(records)) {
    vwritef("* There are no packages currently installed -- nothing to rebuild.")
    return(invisible(records))
  }

  # subset packages based on user request
  packages <- setdiff(packages %||% names(records), "renv")
  records <- named(records[packages], packages)

  # for any packages that are missing, use the latest available instead
  records <- enumerate(records, function(package, record) {
    record %||% renv_available_packages_latest(package) %||% {
      fmt <- "package '%s' is not available"
      stopf(fmt, package)
    }
  })

  # apply any overrides
  records <- renv_records_override(records)

  # notify the user
  preamble <- if (recursive)
    "The following package(s) and their dependencies will be reinstalled:"
  else
    "The following package(s) will be reinstalled:"

  renv_pretty_print_records(records, preamble)

  if (prompt && !proceed()) {
    renv_report_user_cancel()
    return(invisible(records))
  }

  # figure out rebuild parameter
  rebuild <- if (recursive) NA else packages

  # perform the install
  install(
    packages = records,
    library  = libpaths,
    type     = type,
    rebuild  = rebuild,
    project  = project
  )
}
