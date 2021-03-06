#!/usr/bin/Rscript
### SIAMCAT - Statistical Inference of Associations between
### Microbial Communities And host phenoTypes R flavor EMBL
### Heidelberg 2012-2018 GNU GPL 3.0

#' @title Model training
#'
#' @description This function trains the a machine learning model on the
#' training data
#'
#' @usage train.model(siamcat, method = c("lasso", "enet", "ridge", "lasso_ll",
#' "ridge_ll", "randomForest"), stratify = TRUE, modsel.crit = list("auc"),
#' min.nonzero.coeff = 1, param.set = NULL, perform.fs = FALSE, param.fs =
#' list(thres.fs = 100, method.fs = "AUC", direction='absolute'),
#' feature.type='normalized', verbose = 1)
#'
#' @param siamcat object of class \link{siamcat-class}
#'
#' @param method string, specifies the type of model to be trained, may be one
#' of these: \code{c('lasso', 'enet', 'ridge', 'lasso_ll', 'ridge_ll',
#' 'randomForest')}
#'
#' @param stratify boolean, should the folds in the internal cross-validation be
#' stratified?, defaults to \code{TRUE}
#'
#' @param modsel.crit list, specifies the model selection criterion during
#' internal cross-validation, may contain these: \code{c('auc', 'f1', 'acc',
#' 'pr')}, defaults to \code{list('auc')}
#'
#' @param min.nonzero.coeff integer number of minimum nonzero coefficients that
#' should be present in the model (only for \code{'lasso'}, \code{'ridge'},
#' and \code{'enet'}), defaults to \code{1}
#'
#' @param param.set list, set of extra parameters for mlr run, may contain:
#' \itemize{ \item \code{cost} and \code{class.weights} - for lasso_ll and
#' ridge_ll \item \code{alpha} - for enet \item \code{ntree} and \code{mtry} -
#' for RandomForrest. } See below for details. Defaults to \code{NULL}
#'
#' @param perform.fs boolean, should feature selection be performed? Defaults to
#' \code{FALSE}
#'
#' @param param.fs list, parameters for the feature selection, must contain:
#' \itemize{ \item \code{thres.fs} - threshold for the feature selection,
#' \item \code{method.fs} - method for the feature selection, may be
#' \code{AUC}, \code{gFC}, or \code{Wilcoxon} \item \code{direction} - for
#' \code{AUC} and \code{gFC}, select either the top associated features
#' (independent of the sign of enrichment), the top positively associated
#' featured, or the top negatively associated features, may be
#' \code{absolute}, \code{positive}, or \code{negative}. Will be ignored for
#' \code{Wilcoxon}. } See Details for more information. Defaults to
#' \code{list(thres.fs=100, method.fs="AUC", direction='absolute')}
#'
#' @param feature.type string, on which type of features should the function
#' work? Can be either \code{"original"}, \code{"filtered"}, or
#' \code{"normalized"}. Please only change this paramter if you know what you
#' are doing!
#'
#' @param verbose integer, control output: \code{0} for no output at all,
#' \code{1} for only information about progress and success, \code{2} for
#' normal level of information and \code{3} for full debug information,
#' defaults to \code{1}
#'
#' @export
#'
#' @keywords SIAMCAT plm.trainer
#'
#' @return object of class \link{siamcat-class} with added \code{model_list}
#'
#' @details This functions performs the training of the machine learning model
#' and functions as an interface to the \code{mlr}-package.
#'
#' The function expects a \link{siamcat-class}-object with a prepared
#' cross-validation (see \link{create.data.split}) in the
#' \code{data_split}-slot of the object. It then trains a model for each fold
#' of the datasplit.
#'
#' For the machine learning methods that require additional hyperparameters
#' (e.g. \code{lasso_ll}), the optimal hyperparameters are tuned with the
#' function \link[mlr]{tuneParams} within the \code{mlr}-package.
#'
#' The different machine learning methods are implemented as mlr-tasks:
#' \itemize{ \item \code{'lasso'}, \code{'enet'}, and \code{'ridge'} use the
#' \code{'classif.cvglmnet'} Learner, \item \code{'lasso_ll'} and
#' \code{'ridge_ll'} use the \code{'classif.LiblineaRL1LogReg'} and the
#' \code{'classif.LiblineaRL2LogReg'} Learners respectively \item
#' \code{'randomForest'} is implemented via the \code{'classif.randomForest'}
#' Learner. }
#'
#' \strong{Hyperparameters} You also have additional control over the machine
#' learning procedure by supplying information through the \code{param.set}
#' parameter within the function. We encourage you to check out the excellent
#' \href{https://mlr.mlr-org.com/index.html}{mlr documentation} for more
#' in-depth information.
#'
#' Here is a short overview which parameters you can supply in which form:
#' \itemize{
#' \item enet The \strong{alpha} parameter describes the mixture between
#' lasso and ridge penalty and is -per default- determined using internal
#' cross-validation (the default would be equivalent to
#' \code{param.set=list('alpha'=c(0,1))}). You can supply either the limits of
#' the hyperparameter exploration (e.g. with limits 0.2 and 0.8:
#' \code{param.set=list('alpha'=c(0.2,0.8))}) or you can supply a fixed alpha
#' value as well (\code{param.set=list('alpha'=0.5)}).
#' \item lasso_ll/ridge_ll You can supply both \strong{class.weights} and
#' the \strong{cost} parameter (cost of the constraints violation, see
#' \link[LiblineaR]{LiblineaR} for more info). The default values would be
#' equal to \code{param.set=list('class.weights'=c(5, 1),
#' 'cost'=c(10 ^ seq(-2, 3, length = 6 + 5 + 10))}.
#' \item randomForest You can supply the two parameters \strong{ntree}
#' (Number of trees to grow) and \strong{mtry} (Number of variables randomly
#' sampled as candidates at each split). See also
#' \link[randomForest]{randomForest} for more info. The default values
#' correspond to
#' \code{param.set=list('ntree'=c(100, 1000), 'mtry'=
#' c(round(sqrt.mdim / 2), round(sqrt.mdim), round(sqrt.mdim * 2)))} with
#' \code{sqrt.mdim=sqrt(nrow(data))}.
#' }
#'
#'
#' \strong{Feature selection} The function can also perform feature selection
#' on each individual fold. At the moment, three methods for feature selection
#' are implemented: \itemize{ \item \code{'AUC'} - computes the Area Under the
#' Receiver Operating Characteristics Curve for each single feature and
#' selects the top \code{param.fs$thres.fs}, e.g. 100 features \item
#' \code{'gFC'} - computes the generalized Fold Change (see
#' \link{check.associations}) for each feature and likewise selects the top
#' \code{param.fs$thres.fs}, e.g. 100 features \item \code{Wilcoxon} -
#' computes the p-Value for each single feature with the Wilcoxon test and
#' selects features with a p-value smaller than \code{param.fs$thres.fs} } For
#' \code{AUC} and \code{gFC}, feature selection can also be directed, that
#' means that the features will be selected either based on the overall
#' association (\code{absolute} - \code{gFC} will be converted to absolute
#' values and \code{AUC} values below \code{0.5} will be converted by \code{1
#' - AUC}), or on associations in a certain direction (\code{positive} -
#' positive enrichment as measured by positive values of the \code{gFC} or
#' \code{AUC} values higher than  \code{0.5} - and reversely for
#' \code{negative}).
#' @examples
#' data(siamcat_example)
#'
#' # simple working example
#' siamcat_example <- train.model(siamcat_example, method='lasso')
train.model <- function(siamcat,
    method = c("lasso",
        "enet",
        "ridge",
        "lasso_ll",
        "ridge_ll",
        "randomForest"),
    stratify = TRUE,
    modsel.crit = list("auc"),
    min.nonzero.coeff = 1,
    param.set = NULL,
    perform.fs = FALSE,
    param.fs = list(thres.fs = 100, method.fs = "AUC", direction="absolute"),
    feature.type='normalized',
    verbose = 1) {

    if (verbose > 1)
        message("+ starting train.model")
    s.time <- proc.time()[3]

    # check and get features
    if (!feature.type %in% c('original', 'filtered', 'normalized')){
        stop("Unrecognised feature type, exiting...\n")
    }
    if (feature.type == 'original'){
        feat <- get.orig_feat.matrix(siamcat)
    } else if (feature.type == 'filtered'){
        if (is.null(filt_feat(siamcat, verbose=0))){
            stop('Features have not yet been filtered, exiting...\n')
        }
        feat <- get.filt_feat.matrix(siamcat)
    } else if (feature.type == 'normalized'){
        if (is.null(norm_feat(siamcat, verbose=0))){
            stop('Features have not yet been normalized, exiting...\n')
        }
        feat <- get.norm_feat.matrix(siamcat)
    }

    # make sure the names fit
    rownames(feat) <- make.names(rownames(feat))

    # checks
    label <- label(siamcat)
    if (label$type == "TEST"){
        stop('Model can not be trained to SIAMCAT object with a TEST label.',
            ' Exiting...')
    }
    if (is.null(data_split(siamcat, verbose=0))){
        stop("SIAMCAT object needs a data split for model training! Exiting...")
    }
    data.split <- data_split(siamcat)

    # check modsel.crit
    if (!all(modsel.crit %in% c("auc", "f1", "acc", "pr", "auprc"))) {
        warning("Unkown model selection criterion... Defaulting to AU-ROC!\n")
        measure <- list(mlr::auc)
    } else {
        measure <- list()
    }
    if (verbose > 2)
        message("+++ preparing selection measures")
    for (m in modsel.crit) {
        if (m == "auc") {
            measure[[length(measure) + 1]] <- mlr::auc
        } else if (m == "acc") {
            measure[[length(measure) + 1]] <- mlr::acc
        } else if (m == "f1") {
            measure[[length(measure) + 1]] <- mlr::f1
        } else if (m == "pr" || m == "auprc") {
            auprc <- makeMeasure(
                id = "auprc",
                minimize = FALSE,
                best = 1,
                worst = 0,
                properties = c("classif", "req.pred",
                    "req.truth", "req.prob"),
                name = "Area under the Precision
                Recall Curve",
                fun = function(task,
                    model,
                    pred,
                    feats,
                    extra.args) {
                    measureAUPRC(
                        getPredictionProbabilities(pred),
                        pred$data$truth,
                        pred$task.desc$negative,
                        pred$task.desc$positive
                    )
                }
            )
            measure[[length(measure) + 1]] <- auprc
        }
    }

    # Create matrix with hyper parameters.
    hyperpar.list <- list()

    # Create List to save models.
    models.list <- list()
    num.runs <- data.split$num.folds * data.split$num.resample
    bar <- 0
    if (verbose > 1)
        message(paste("+ training", method, "models on", num.runs,
            "training sets"))

    if (verbose > 1 & perform.fs){
        message('+ Performing feature selection ',
            'with following parameters:')
        for (i in seq_along(param.fs)) {
            message(paste0('    ', names(param.fs)[i], ' = ',
                ifelse(is.null(param.fs[[i]]), 'NULL', param.fs[[i]])))
            }
        }

    if (verbose == 1 || verbose == 2)
        pb <- progress_bar$new(total = num.runs)

    for (fold in seq_len(data.split$num.folds)) {
        if (verbose > 2)
            message(paste("+++ training on cv fold:", fold))

        for (resampling in seq_len(data.split$num.resample)) {
            if (verbose > 2)
                message(paste("++++ repetition:", resampling))

            fold.name <-
                paste0("cv_fold",
                    as.character(fold),
                    "_rep",
                    as.character(resampling))
            fold.exm.idx <- match(data.split$
                training.folds[[resampling]][[fold]],
                names(label$label))

            ### subselect examples for training
            label.fac <-
                factor(label$label,
                    levels = sort(label$info))
            train.label <- label.fac[fold.exm.idx]
            data <-
                as.data.frame(t(feat)[fold.exm.idx,])
            stopifnot(nrow(data) == length(train.label))
            stopifnot(all(rownames(data) == names(train.label)))

            #feature selection
            if (perform.fs) {

                stopifnot(all(c('method.fs', 'thres.fs', 'direction') %in%
                    names(param.fs)))

                # test method.fs
                if (!param.fs$method.fs %in% c('Wilcoxon', 'AUC', 'gFC')) {
                    stop('Unrecognised feature selection method...\n')
                }

                # assert the threshold
                if (param.fs$method.fs == 'Wilcoxon') {
                    stopifnot(param.fs$thres.fs < 1 && param.fs$thres.fs > 0)
                } else {
                    stopifnot(param.fs$thres.fs > 10)
                }
                stopifnot(param.fs$thres.fs < ncol(data))

                if (param.fs$method.fs == 'Wilcoxon') {
                    assoc <- vapply(data,
                                    FUN=function(x, label){
                                        d <- data.frame(x=x, y=label);
                                        t <- wilcox.test(x~y, data=d)
                                        return(t$p.val)
                                    },
                                    FUN.VALUE=double(1),
                                    label=train.label)
                    data <- data[,which(assoc < param.fs$thres.fs)]
                } else if (param.fs$method.fs == 'AUC') {
                    assoc <- vapply(data,
                                    FUN=get.single.feat.AUC,
                                    FUN.VALUE = double(1),
                                    label=train.label,
                                    pos=max(label$info),
                                    neg=min(label$info))
                    if (param.fs$direction == 'absolute'){
                        assoc[assoc < 0.5] <- 1 - assoc[assoc < 0.5]
                    } else if (param.fs$direction == 'negative'){
                        assoc <- 1 - assoc
                    }
                    asso <- assoc[assoc > 0.5]
                    data <- data[,names(which(
                        rank(-assoc) <= param.fs$thres.fs))]
                } else if (param.fs$method.fs == 'gFC') {
                    assoc <- vapply(data,
                                    FUN=get.quantile.FC,
                                    FUN.VALUE = double(1),
                                    label=train.label,
                                    pos=max(label$info),
                                    neg=min(label$info))
                    if (param.fs$direction == 'absolute'){
                        assoc <- abs(assoc)
                    } else if (param.fs$direction == 'negative'){
                        assoc <- -assoc
                    }
                    assoc <- assoc[assoc > 0]
                    data <- data[,names(which(
                        rank(-assoc) <= param.fs$thres.fs))]

                }

                stopifnot(ncol(data) > 0)
                if (verbose > 2) {
                    message(paste0('++ retaining ', ncol(data),
                        ' features after feature selection with ',
                        param.fs$method.fs, '-threshold ',
                        param.fs$thres.fs))
                    }
            }

            data$label <- train.label

            ### internal cross-validation for model selection
            model <-
                train.plm(
                    data = data,
                    method = method,
                    measure = measure,
                    min.nonzero.coeff = min.nonzero.coeff,
                    param.set = param.set,
                    neg.lab = min(label$info)
                )
            bar <- bar + 1

            if (!all(model$feat.weights == 0)) {
                models.list[[bar]] <- model
            } else {
                warning("Model without any features selected!\n")
            }

            if (verbose == 1 || verbose == 2)
                pb$tick()
        }
    }

    model_list(siamcat) <- list(
        models = models.list,
        model.type = method,
        feature.type = feature.type)

    e.time <- proc.time()[3]

    if (verbose > 1)
        message(paste(
            "+ finished train.model in",
            formatC(e.time - s.time,
                digits = 3),
            "s"
        ))
    if (verbose == 1)
        message(paste("Trained", method, "models successfully."))

    return(siamcat)
}

#' @keywords internal
measureAUPRC <- function(probs, truth, negative, positive) {
    pr <- pr.curve(scores.class0 = probs[which(truth == positive)],
        scores.class1 = probs[which(truth == negative)])
    return(pr$auc.integral)
}

#' @keywords internal
get.single.feat.AUC <- function(x, label, pos, neg) {
    x.p <- x[label == pos]
    x.n <- x[label == neg]
    temp.auc <- roc(cases=x.p, controls=x.n, direction='<')$auc
    return(temp.auc)
}

#' @keywords internal
get.quantile.FC <- function(x, label, pos, neg){
    x.p <- x[label == pos]
    x.n <- x[label == neg]
    q.p <- quantile(x.p, probs=seq(.1, .9, length.out=9))
    q.n <- quantile(x.n, probs=seq(.1, .9, length.out=9))
    return(sum(q.p - q.n)/length(q.p))
}
