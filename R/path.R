
`_renv_alpha` <- c(letters, LETTERS)

renv_path_absolute <- function(path) {

  substr(path, 1L, 1L) %in% c("~", "/", "\\") || (
    substr(path, 1L, 1L) %in% `_renv_alpha` &&
    substr(path, 2L, 3L) %in% c(":/", ":\\")
  )

}

renv_path_within <- function(path, parent) {
  path <- renv_path_canonicalize(path)
  prefix <- paste(renv_path_canonicalize(parent), "/", sep = "")
  path == parent | substring(path, 1L, nchar(prefix)) == prefix
}

renv_path_normalize <- function(path, winslash = "/", mustWork = FALSE) {
  if (renv_platform_unix())
    renv_path_normalize_unix(path, winslash, mustWork)
  else
    renv_path_normalize_win32(path, winslash, mustWork)
}

renv_path_normalize_unix <- function(path,
                                     winslash = "/",
                                     mustWork = FALSE)
{
  # force paths to be absolute
  bad <- !map_lgl(path, renv_path_absolute)
  if (any(bad)) {
    prefix <- normalizePath(".", winslash = winslash)
    path[bad] <- paste(prefix, path[bad], sep = winslash)
  }

  # normalize the expanded paths
  normalizePath(path, winslash, mustWork)
}

# NOTE: in versions of R < 4.0.0, normalizePath() does not normalize path
# casing; e.g. normalizePath("~/MyPaTh") will not normalize to "~/MyPath"
# (assuming that is the "true" underlying casing on the filesystem)
#
# we work around this by round-tripping between the short name and
# the long name, as Windows then has no choice but to figure out
# the correct casing for us
#
# this isn't 100% reliable (not all paths have a short-path equivalent)
# but seems to be good enough in practice ...
#
# except that, if the path contains characters that cannot be represented in the
# current encoding, then attempting to normalize the short version of that path
# will fail -- so if the path is already UTF-8, then we need to avoid
# round-tripping through the short path.
#
# furthermore, it appears that shortPathName() can mis-encode its result for
# strings marked with latin1 encoding?
#
# https://github.com/rstudio/renv/issues/629
renv_path_normalize_win32 <- function(path,
                                      winslash = "/",
                                      mustWork = FALSE)
{

  # see the NOTE above, this workaround is only necessary for R < 4.0.0,
  # and it complicates things unnecessarily
  if (getRversion() >= "4.0.0")
    return(renv_path_normalize_unix(path, winslash, mustWork))

  # get encoding for this set of paths
  enc <- Encoding(path)

  # perform separate operations for each
  utf8    <- enc == "UTF-8"
  latin1  <- enc == "latin1"
  unknown <- enc == "unknown"

  # normalize based on their encoding
  path[utf8]    <- normalizePath(path[utf8], winslash, mustWork)
  path[latin1]  <- normalizePath(path[latin1], winslash, mustWork)
  path[unknown] <- renv_path_normalize_win32_impl(path[unknown], winslash, mustWork)

  # return resulting path
  path
}

renv_path_normalize_win32_impl <- function(path,
                                           winslash = "/",
                                           mustWork = FALSE)
{
  short <- utils::shortPathName(path.expand(path))
  normalizePath(short, winslash, mustWork)
}

# TODO: this is a lie; for existing paths symlinks will be resolved
renv_path_canonicalize <- function(path) {
  parent <- dirname(path)
  root <- renv_path_normalize(parent, winslash = "/", mustWork = FALSE)
  trimmed <- sub("/+$", "", root)
  file.path(trimmed, basename(path))
}

renv_path_same <- function(lhs, rhs) {
  renv_path_canonicalize(lhs) == renv_path_canonicalize(rhs)
}

# get the nth path component from the end of the path
renv_path_component <- function(path, index = 1) {
  splat <- strsplit(path, "[/\\]+")
  map_chr(splat, function(parts) parts[length(parts) - index + 1])
}

renv_path_pretty <- function(path) {
  renv_json_quote(aliased_path(path))
}
