% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/catalog_apply.r
\name{catalog_apply}
\alias{catalog_apply}
\title{LAScatalog processing engine}
\usage{
catalog_apply(ctg, FUN, ..., .options = NULL)
}
\arguments{
\item{ctg}{A \link[lidR:LAScatalog-class]{LAScatalog} object.}

\item{FUN}{A user-defined function that respects a given template (see section function template)}

\item{...}{Optional arguments to FUN.}

\item{.options}{See dedicated section and example.}
}
\description{
This function gives users access to the \link[lidR:LAScatalog-class]{LAScatalog} processing engine.
It allows the application of a user-defined routine over an entire catalog. The LAScatalog
processing engine tool is explained in the \link[lidR:LAScatalog-class]{LAScatalog class}\cr\cr
\strong{Warning:} the LAScatalog processing engine has a mechanism to load buffered data to avoid
edge artifacts, but no mechanism to remove the buffer after applying user-defined functions, since
this task is specific to each process. In other \code{lidR} functions this task is performed
specifically for each function. In \code{catalog_apply} the user's function can return any output,
thus users must take care of this task themselves (See section "Edge artifacts")
}
\section{Edge artifacts}{


It is important to take precautions to avoid 'edge artifacts' when processing wall-to-wall
tiles. If the points from neighboring tiles are not included during certain processes,
this could create 'edge artifacts' at the tile boundaries. For example, empty or incomplete
pixels in a rasterization process, or dummy elevations in a ground interpolation. The LAScatalog
processing engine provides internal tools to load buffered data. However, there is
no mechanism to remove the results computed in the buffered area since this task depends on the
output of the user-defined function. The user must take care of this task (see examples).
}

\section{Buffered data}{


The LAS objects read by the user function have a special attribute called 'buffer' that indicates,
for each point, if it comes from a buffered area or not. Points from non-buffered areas have a
'buffer' value of 0, while points from buffered areas have a 'buffer' value of 1, 2, 3 or 4, where
1 is the bottom buffer and 2, 3 and 4 are the left, top and right buffers, respectively.
}

\section{Function template}{


The parameter \code{FUN} expects a function with a first argument that will be supplied automatically
by the \code{LAScatalog} processing engine. This first argument is a \code{LAScluster}. A \code{LAScluster}
is an internal undocumented class but the user needs to know only three things about this class:
\itemize{
\item It represents a chunk of the catalog
\item The function \link{readLAS} can be used with a \code{LAScluster}
\item The function \link[raster:extent]{extent} or \link[sp:bbox]{bbox} can be used with a \code{LAScluster}
and it returns the bounding box of the cluster without the buffer. It can be used to clip the output
and remove the buffered region (see examples).
}
A user-defined function must be templated like this:
\preformatted{
myfun = function(cluster, ...)
{
   las = readLAS(cluster)
   if (is.empty(las)) return(NULL)
   # do something
   # remove the buffer of the output
   return(something)
}}
The line \code{if(is.empty(las)) return(NULL)} is important because some clusters (chunks) may contain
0 points (we can't know that before reading the file). In this case an empty point cloud with 0 points
is returned by \code{readLAS} and this may fail in subsequent code. Thus, exiting early from the user-defined
function by returning \code{NULL} indicates to the internal engine that the cluster was empty.
}

\section{.options}{

User may have noticed that some lidR functions throw an errors when the processing options are inappropriate.
For example, some functions need a buffer and thus \code{buffer = 0} is forbidden. User can add the same
constrains to protect against inappropriate options. The \code{.options} argument can be a \code{list} of
options.
\itemize{
\item \code{need_buffer = TRUE} the function complains if the buffer is 0
\item \code{need_output_file = TRUE} the function complains if no output file template is provided
\item \code{drop_null = FALSE} the NULL outputs are not automatically removed (useful in very
specific internal cases)
\item \code{raster_alignment = ...} very important option, see below.
}

When the function \code{FUN} returns a raster it is important to ensure that the chunks are aligned
with the raster to avoid edge artifacts. Indeed, if the edge of a chunk does not correspond to the edge
of the pixels the output will not be strictly continuous and will have edge artifacts (that might
not be visible). Users can check this with the options \code{raster_alignment}, that  can take the
resolution of the raster as input, as well as the starting point if needed. The following are accepted:\cr\cr
\preformatted{
# check if the chunks are aligned with a raster of resolution 20
raster_alignment = 20
raster_alignment = list(res = 20)

# check if chunks are aligned with a raster of resolution 20
# that starts a (0,10)
raster_alignment = list(res = 20, start = c(0,10))
}
See also \link{grid_metrics} for more details.
}

\section{Supported processing options}{

Supported processing options for a \code{LAScatalog} (in bold). For more details see the
\link[lidR:LAScatalog-class]{LAScatalog engine documentation}:
\itemize{
\item \strong{chunk_size}: How much data is loaded at once.
\item \strong{chunk_buffer}: Load chunks with a buffer.
\item \strong{chunk_alignment}: Align the chunks.
\item \strong{cores}: How many chunks are loaded and processed at once.
\item \strong{progress}: Displays a progress estimate.
\item \strong{output_files}: The user-defined function outputs will be written to files instead of being
returned into R.
\item \strong{laz_compression}: write \code{las} or \code{laz} files only if the user-defined function
returns a \code{LAS} object.
\item \strong{select}: Select only the data of interest to save processing memory.
\item \strong{filter}: Read only the points of interest.
}
}

\examples{
# More examples might be avaible in the official lidR vignettes or
# on the github wiki <http://jean-romain.github.io/lidR/wiki>

## =========================================================================
## Example 1: detect all the tree tops over an entire catalog
## (this is basically the reproduction of existing lidR function 'tree_detection')
## =========================================================================

# 1. Build the user-defined function that analyzes each chunk of the catalog.
# The function's first argument is a LAScluster object. The other arguments can be freely
# choosen by the user.
my_tree_detection_method <- function(cluster, ws)
{
  # The cluster argument is a LAScluster object. The user does not need to know how it works.
  # readLAS will load the region of interest (chunk) with a buffer around it, taking advantage of
  # point cloud indexation if possible. The filter and select options are propagated automatically
  las <- readLAS(cluster)
  if (is.empty(las)) return(NULL)

  # Find the tree tops using a user-developed method (here simply a LMF).
  ttops <- tree_detection(las, lmf(ws))

  # ttops is a SpatialPointsDataFrame that contains the tree tops in our region of interest
  # plus the trees tops in the buffered area. We need to remove the buffer otherwise we will get
  # some trees more than once.
  bbox  <- raster::extent(cluster)
  ttops <- raster::crop(ttops, bbox)

  return(ttops)
}

# 2. Build a project (here, a single file catalog for the purposes of this dummmy example).
LASfile <- system.file("extdata", "MixedConifer.laz", package="lidR")
project <- catalog(LASfile)
plot(project)

# 3. Set some catalog options.
# For this dummy example, the chunk size is 80 m and the buffer is 10 m using a single core.
opt_chunk_buffer(project) <- 10
opt_cores(project)        <- 1L
opt_chunk_size(project)   <- 80            # small because this is a dummy example.
opt_select(project)       <- "xyz"         # read only the coordinates.
opt_filter(project)       <- "-keep_first" # read only first returns.

# 4. Apply a user-defined function to take advantage of the internal engine
opt    <- list(need_buffer = TRUE)   # catalog_apply will throw an error if buffer = 0
output <- catalog_apply(project, my_tree_detection_method, ws = 5, .options = opt)

# 5. Post-process the output to merge the results (depending on the output computed).
# Here, each value of the list is a SpatialPointsDataFrame, so rbind does the job:
output <- do.call(rbind, output)
spplot(output)

## ===================================================
## Example 2: compute a rumple index on surface points
## ===================================================

rumple_index_surface = function(cluster, res)
{
  las = readLAS(cluster)
  if (is.empty(las)) return(NULL)

  las    <- lasfiltersurfacepoints(las, 1)
  rumple <- grid_metrics(las, rumple_index(X,Y,Z), res)
  bbox   <- raster::extent(cluster)
  rumple <- raster::crop(rumple, bbox)

  return(rumple)
}

LASfile <- system.file("extdata", "Megaplot.laz", package="lidR")
project <- catalog(LASfile)

opt_chunk_buffer(project) <- 1
opt_cores(project)        <- 1L
opt_chunk_size(project)   <- 120     # small because this is a dummy example.
opt_select(project)       <- "xyz"   # read only the coordinates.

opt     <- list(raster_alignment = 20)  # catalog_apply will adjust the chunks if required
output  <-  catalog_apply(project, rumple_index_surface, res = 20, .options = opt)
output  <- do.call(raster::merge, output)
plot(output, col = height.colors(50))
}
