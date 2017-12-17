###
# SIAMCAT -  Statistical Inference of Associations between Microbial Communities And host phenoTypes
# RScript flavor
#
# written by Georg Zeller
# with additions by Nicolai Karcher and Konrad Zych
# EMBL Heidelberg 2012-2017
#
# version 0.2.0
# file last updated: 25.06.2017
# GNU GPL 3.0
###

##### function to train a LASSO model for a single given C
#' @export
train.plm <- function(data, method = c("lasso", "enet", "ridge", "lasso_ll", "ridge_ll", "randomForest"),
                      measure=list("acc"), min.nonzero.coeff=5){
  #model <- list(original.model=NULL, feat.weights=NULL)

  ## 1) Define the task
  ## Specify the type of analysis (e.g. classification) and provide data and response variable
  task      <- makeClassifTask(data = data, target = "label")

  ## 2) Define the learner
  ## Choose a specific algorithm (e.g. linear discriminant analysis)
  cl        <- "classif.cvglmnet" ### the most ocommon learner defined her so taht this does not have done multiple times
  paramSet  <- NULL
  cost      <- c(0.001, 0.003, 0.01, 0.03, 0.1, 0.3, 1, 3, 10)

  if(method == "lasso"){
    lrn       <- makeLearner(cl, predict.type="prob", 'nlambda'=100, 'alpha'=1)
  } else if(method == "ridge"){
    lrn       <- makeLearner(cl, predict.type="prob", 'nlambda'=100, 'alpha'=0)
  } else if(method == "enet"){
    lrn       <- makeLearner(cl, predict.type="prob", 'nlambda'=10)
    paramSet  <- makeParamSet(makeNumericParam('alpha', lower=0, upper=1))
  } else if(method == "lasso_ll"){
    cl        <- "classif.LiblineaRL1LogReg"
    lrn       <- makeLearner(cl, predict.type="prob", epsilon=1e-6)
    paramSet  <- makeParamSet(makeDiscreteParam("cost", values=cost))
  } else if(method == "ridge_ll"){
    cl        <- "classif.LiblineaRL2LogReg"
    lrn       <- makeLearner(cl, predict.type="prob", epsilon=1e-6, type=0)
    paramSet  <- makeParamSet(makeDiscreteParam("cost", values=cost))
  } else if(method == "randomForest"){
    sqrt.mdim <- sqrt(nrow(data))
    cl        <- "classif.randomForest"
    lrn       <- makeLearner(cl, predict.type = "prob", fix.factors.prediction = TRUE)
    paramSet  <- makeParamSet(makeNumericParam('ntree', lower=100, upper=1000),
                        makeDiscreteParam('mtry', values=c(round(sqrt.mdim/2), round(sqrt.mdim), round(sqrt.mdim*2))))
  } else {
    stop(method, " is not a valid method, currently supported: lasso, enet, ridge, libLineaR, randomForest.\n")
  }


  ## 3) Fit the model
  ## Train the learner on the task using a random subset of the data as training set
  if(!all(is.null(paramSet))){
    hyperPars <- tuneParams(learner = lrn,
                         task = task,
                         resampling =  makeResampleDesc('CV', iters=5L, stratify=TRUE),
                         par.set = paramSet,
                         control = makeTuneControlGrid(resolution = 10L),
                         measures=measure)
    print(hyperPars)
    lrn       <- setHyperPars(lrn, par.vals=hyperPars$x)
  }

  model     <- train(lrn, task)

  if(cl == "classif.cvglmnet"){
    opt.lambda           <- get.optimal.lambda.for.glmnet(model, task, measure, min.nonzero.coeff)
    # cat(opt.lambda, '\n')
    # transform model
    if (is.null(model$learner$par.vals$s)){
      model$learner.model$lambda.1se <- opt.lambda
    } else {
      model$learner.model[[model$learner$par.vals$s]] <- opt.lambda
    }
    coef                <- coefficients(model$learner.model)
    bias.idx            <- which(rownames(coef) == '(Intercept)')
    coef                <- coef[-bias.idx,]
    model$feat.weights  <- (-1) *  as.numeric(coef) ### check!!!
  } else if(cl == "classif.LiblineaRL1LogReg"){
    model$feat.weights  <-model$learner.model$W[-which(colnames(model$learner.model$W)=="Bias")]
  } else if(cl == "classif.randomForest"){
    model$feat.weights  <-model$learner.model$importance
  }

  model$lrn          <- lrn ### ???
  model$task         <- task

  return(model)
}

#' @export
get.foldList <- function(data.split){
  num.runs     <- 1
  num.folds    <- 2
  fold.name = list()
  fold.exm.idx = list()
  if (is.null(data.split)){
    # train on whole data set
    fold.name[[1]]    <- 'whole data set'
    fold.exm.idx[[1]] <- names(label$label)
  } else {
    if (class(data.split) == 'character') {
      # read in file containing the training instances
      num.runs      <- 0
      con           <- file(data.split, 'r')
      input         <- readLines(con)
      close(con)
      #print(length(input))

      num.folds     <- as.numeric(strsplit(input[[3]],"#")[[1]][2])
      for (i in 1:length(input)) {
        l               <- input[[i]]
        if (substr(l, 1, 1) != '#') {
          num.runs                 <- num.runs + 1
          s                        <- unlist(strsplit(l, '\t'))
          fold.name[[num.runs]]    <- substr(s[1], 2, nchar(s[1]))
          ### Note that the %in%-operation is order-dependend.
          fold.exm.idx[[num.runs]] <- which(names(label$label) %in% as.vector(s[2:length(s)]))
          cat(fold.name[[num.runs]], 'contains', length(fold.exm.idx[[num.runs]]), 'training examples\n')
          #      cat(fold.exm.idx[[num.runs]], '\n\n')
          #    } else {
          #      cat('Ignoring commented line:', l, '\n\n')
        }
      }
    } else if (class(data.split) == 'list') {
      # use training samples as specified in training.folds in the list
      num.folds <- data.split$num.folds
      num.runs <- 0
      for (cv in 1:data.split$num.folds){
        for (res in 1:data.split$num.resample){
          num.runs <- num.runs + 1

          fold.name[[num.runs]] = paste0('cv_fold', as.character(cv), '_rep', as.character(res))
          fold.exm.idx[[num.runs]] <- match(data.split$training.folds[[res]][[cv]], names(label$label))
          cat(fold.name[[num.runs]], 'contains', length(fold.exm.idx[[num.runs]]), 'training examples\n')
        }
      }
    } else {
      stop('Wrong input for training samples!...')
    }
  }
  fold.name  <- unlist(fold.name)
  stopifnot(length(fold.name) == num.runs)
  stopifnot(length(fold.exm.idx) == num.runs)
  invisible(list(fold.name = fold.name,fold.exm.idx = fold.exm.idx, num.runs = num.runs, num.folds = num.folds))
}


get.optimal.lambda.for.glmnet <- function(trained.model, training.task, perf.measure, min.nonzero.coeff){
  # get lambdas that fullfill the minimum nonzero coefficients criterion
  lambdas <- trained.model$learner.model$glmnet.fit$lambda[which(trained.model$learner.model$nzero >= min.nonzero.coeff)]
  # get performance on training set for all those lambdas in trace
  performances <- sapply(lambdas, FUN=function(lambda, model, task, measure){
    model.transformed <- model
    # lambda.1se is the default parameter value, but could in principle be set be the user.... will not have an effect though...
    if (is.null(model.transformed$learner$par.vals$s)){
      model.transformed$learner.model$lambda.1se <- lambda
    } else {
      model.transformed$learner.model[[model.transformed$learner$par.vals$s]] <- lambda
    }
    pred.temp <- predict(model.transformed, task)
    performance(pred.temp, measures = measure)
  }, model=trained.model, task=training.task, measure=perf.measure)
  # get optimal lambda in depence of the performance measure
  if (length(perf.measure) == 1){
    if (perf.measure[[1]]$minimize == TRUE){
      opt.lambda <- lambdas[which(performances == min(performances))[1]]
    } else {
      opt.lambda <- lambdas[which(performances == max(performances))[1]]
    }
  } else {
    opt.idx <- c()
    for (m in 1:length(perf.measure)){
      if (perf.measure[[m]]$minimize == TRUE){
        opt.idx <- c(opt.idx, which(performances[m,] == min(performances[m,]))[1])
      } else {
        opt.idx <- c(opt.idx, which(performances[m,] == max(performances[m,]))[1])
      }
    }
    opt.lambda <- lambdas[floor(mean(opt.idx))]
  }
  return(opt.lambda)
}
