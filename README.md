# Strata Hadoop World 2017 Exploration with R Tutorial

Welcome to the repository for the ["Exploration and visualization of large, complex datasets with R, Hadoop, and Spark"](https://conferences.oreilly.com/strata/strata-ca/public/schedule/detail/55818) tutorial that will be given by Steve Elston of [Quantia Analytics](http://quantiaanalytics.com/) and [Ryan Hafen](http://ryanhafen.com) at Strata Hadoop World on Tuesday, March 14, 2017, 9:00am–12:30pm.

## Installation

To ensure that we can focus as much time as possible on content during the tutorial, please follow the installation instructions below prior to the day of the tutorial and run the final check to make sure your system is set up appropriately. The examples and exercises will be run locally on your own system, allowing you to continue to experiment with the techniques beyond the tutorial.

If you encounter any issues with installation, please file an issue detailing the problem in this repository including the output of running `sessionInfo()` in your R session. Any known issues and possible workarounds will be documented more prominently at the bottom of this README.

### System prerequisites:

- Latest version of R (3.3.2) (download and install from [here](https://cran.rstudio.com/))
- Latest version of RStudio (download and install from [here](https://www.rstudio.com/products/rstudio/download/))
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

This repository contains all of the resources needed for the course. You can either clone the repository or simply [download the zip file](https://github.com/hafen/strata2017/archive/master.zip) for the repository and unzip it on your computer.

Once you have the repository, you simply need to open up `BigDataVisualization.Rmd` in RStudio and you are ready to go.

## Resources

The following resources can be useful to browse prior to the tutorial to help attendees have a better understanding of some concepts that will be built upon.

- [R for Data Science](http://r4ds.had.co.nz/)
- [dplyr vignette](https://cran.r-project.org/web/packages/dplyr/vignettes/introduction.html)
- [ggplot2 cheatsheet](https://www.rstudio.com/wp-content/uploads/2016/11/ggplot2-cheatsheet-2.1.pdf)
- [SparklyR documentation](http://spark.rstudio.com/dplyr.html)

## Installation issues

If when loading the tidyverse package you get an error like the following:

```
Error : object `as_factor' is not exported by 'namespace:forcats'
Error: package or namespace load failed for `tidyverse'
```

The following should fix it:

```r
remove.packages("tidyverse")
install.packages("forcats")
install.packages("tidyverse")
```

