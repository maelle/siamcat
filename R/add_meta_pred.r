#!/usr/bin/Rscript
###
# SIAMCAT -  Statistical Inference of Associations between Microbial Communities And host phenoTypes
# R flavor
# EMBL Heidelberg 2012-2018
# GNU GPL 3.0
###

#' @title Add metadata as predictors
#' @description This function adds metadata to the feature matrix to be
#'        later used as predictors
#' @param siamcat object of class \link{siamcat-class}
#' @param pred.names vector of names of the metavariables to be added to
#'        the feature matrix as predictors
#' @param std.meta boolean, should added metadata features be standardized?,
#'        defaults to \code{TRUE}
#' @param verbose control output: \code{0} for no output at all, \code{1}
#'        for standard information, defaults to \code{1}
#' @keywords SIAMCAT add.meta.pred
#' @export
#' @return features object with added metadata
add.meta.pred <- function(siamcat, pred.names=NULL, std.meta=TRUE, verbose=1){
  if(verbose>2) cat("+ starting add.meta.pred\n")
  s.time <- proc.time()[3]
  ### add metadata as predictors to the feature matrix
  cnt <- 0

  if (pred.names != '' && !is.null(pred.names)) {
    if(verbose>2) cat("+ starting to add metadata predictors\n")
    for (p in pred.names) {
      if(verbose>2) cat("+++ adding metadata predictor:",p,"\n")
      if(!p%in%colnames(siamcat@phyloseq@sam_data)) stop("There is no metadata variable called ",p,"\n")
      idx <- which(colnames(siamcat@phyloseq@sam_data) == p)
      if(length(idx) != 1) stop(p, "matches multiple columns in the metada\n")

      if (verbose > 0) cat('adding ', p, '\n', sep='')
      m   <-  unlist(siamcat@phyloseq@sam_data[,idx])

      if (!all(is.finite(m))) {
        na.cnt <- sum(!is.finite(m))
        if (verbose > 0) cat('filling in', na.cnt, 'missing values by mean imputation\n')
        mn     <- mean(m, na.rm=TRUE)
        m[!is.finite(m)] <- mn
      }

      if (std.meta) {
        if (verbose > 0) cat('standardize metadata feature', p, '\n')
        m.mean <- mean(m, na.rm = TRUE)
        m.sd   <- sd(m, na.rm = TRUE)
        stopifnot(!m.sd == 0)
        m      <- (m - m.mean)/m.sd
      }

      siamcat@phyloseq@otu_table <- otu_table(rbind(siamcat@phyloseq@otu_table, m),taxa_are_rows=T)
      rownames(siamcat@phyloseq@otu_table)[nrow(siamcat@phyloseq@otu_table)] <- paste('META_', toupper(p), sep='')
      cnt <- cnt + 1
    }
      if (verbose > 0) cat('added', cnt, 'meta-variables as predictors to the feature matrix\n')
  } else {
      if (verbose > 0) cat('Not adding any of the meta-variables as predictor to the feature matrix\n')
  }
  stopifnot(all(!is.na(siamcat@phyloseq@otu_table)))
  e.time <- proc.time()[3]
  if(verbose>2) cat("+ finished add.meta.pred in",e.time-s.time,"s\n")
  return(siamcat)
}
