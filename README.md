# Strata Hadoop World 2017 Exploration with R Tutorial

Welcome to the repository for the "Exploration and visualization of large, complex datasets with R, Hadoop, and Spark" tutorial that will be given at Strata Hadoop World on Tuesday, March 14, 2017, 9:00am–12:30pm.

## Installation

To ensure that we can focus as much time as possible on content during the tutorial, please follow the installation instructions below prior to the day of the tutorial and run the final check to make sure your system is set up appropriately. The examples and exercises will be run locally on your own system, allowing you to continue to experiment with the techniques beyond the tutorial.

If you encounter any issues with installation, please file an issue detailing the problem in this repository including the output of running `sessionInfo()` in your R session.

### System prerequisites:

- Latest version of R (3.3.2) (download and install from [here](https://cran.rstudio.com/))
- Java JDK (download and install from [here](http://www.oracle.com/technetwork/java/javase/downloads/jdk8-downloads-2133151.html))

### R packages

Install the following R packages with the following commands:

```r
install.packages(c("devtools", "tidyverse", "nycflights13", "sparklyr", "digest",
  "scales", "prettyunits", "httpuv", "xtable")
devtools::install_github("hafen/trelliscopejs")
```

Now we can install a local version of Spark with SparklyR's `spark_install()`.

```
library(sparklyr)
spark_install(version = "1.6.2")
```

### Check the installation

Ensure that this example will now run without any issues:

```r
library(sparklyr)
library(dplyr)
library(nycflights13)
library(ggplot2)

sc <- spark_connect(master = "local")
flights <- copy_to(sc, flights, "flights")
airlines <- copy_to(sc, airlines, "airlines")
src_tbls(sc)
filter(flights, dep_delay > 1000)
```

## Course material

We will host the course material and data on this repository. We won't place it here until it is final to avoid conflicts. We will post prior to the tutorial when the material is ready to download or clone.

## Resources

The following resources can be useful to browse prior to the tutorial to help attendees have a better understanding of some concepts that will be built upon.

- [R for Data Science](http://r4ds.had.co.nz/)
- [SparklyR documentation](http://spark.rstudio.com/dplyr.html)
