
renv_lockfile_read_finish_impl <- function(key, val) {

  # convert repository records to named vectors
  # (be careful to handle NAs, NULLs)
  if (identical(key, "Repositories") && is.null(names(val))) {

    getter <- function(name) function(record) record[[name]] %||% "" %NA% ""
    keys <- map_chr(val, getter("Name"))
    vals <- map_chr(val, getter("URL"))

    result <- case(
      empty(keys)       ~ list(),
      any(nzchar(keys)) ~ named(vals, keys),
      TRUE              ~ vals
    )

    return(as.list(result))

  }

  # recurse for lists
  if (is.list(val))
    return(enumerate(val, renv_lockfile_read_finish_impl))

  # return other values as-is
  val

}

renv_lockfile_read_finish <- function(data) {

  # convert repository fields
  data <- enumerate(data, renv_lockfile_read_finish_impl)

  # set class
  class(data) <- "renv_lockfile"
  data

}

renv_lockfile_read_preflight <- function(contents) {

  # check for merge conflict markers
  starts <- grep("^[<]+", contents)
  ends   <- grep("^[>]+", contents)

  hasconflicts <-
    length(starts) &&
    length(ends) &&
    length(starts) == length(ends)

  if (hasconflicts) {

    parts <- .mapply(function(start, end) {
      c(contents[start:end], "")
    }, list(starts, ends), NULL)

    all <- unlist(parts, recursive = TRUE, use.names = FALSE)

    renv_pretty_print(
      values    = head(all, n = -1L),
      preamble  = "The lockfile contains one or more merge conflict markers:",
      postamble = "You will need to resolve these merge conflicts before the file can be read.",
      emitter   = message,
      wrap      = FALSE
    )

    stop("lockfile contains merge conflict markers; cannot proceed", call. = FALSE)

  }

}

renv_lockfile_read <- function(file = NULL, text = NULL) {

  # read the lockfile
  contents <- if (is.null(file))
    unlist(strsplit(text, "\n", fixed = TRUE))
  else
    readLines(file, warn = FALSE, encoding = "UTF-8")

  # check and report some potential errors (e.g. merge conflicts)
  renv_lockfile_read_preflight(contents)
  json <- renv_json_read(text = contents)
  renv_lockfile_read_finish(json)

}
