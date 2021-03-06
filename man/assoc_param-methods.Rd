% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/siamcat_class_accessors.R
\docType{methods}
\name{assoc_param}
\alias{assoc_param}
\alias{assoc_param,siamcat-method}
\alias{assoc_param_param}
\title{Retrieve the list of parameters for association testing from
a SIAMCAT object}
\usage{
assoc_param(siamcat, verbose=1)

\S4method{assoc_param}{siamcat}(siamcat, verbose = 1)
}
\arguments{
\item{siamcat}{(Required). An instance of \link{siamcat-class}
containing the results from association testing}

\item{verbose}{integer, if the slot is empty, should a message be printed?
values can be either \code{0} (no output) or \code{1} (print message)}
}
\value{
A list of parameters for association testing or \code{NULL}
}
\description{
Function to retrieve the list of parameters for
association testing
}
\details{
The function returns the list of parameters used in association
testing. See \link{check.associations} for more details.
}
\examples{
data(siamcat_example)
temp <- assoc_param(siamcat_example)
names(temp)
}
