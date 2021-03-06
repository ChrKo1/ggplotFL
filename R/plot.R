# plot.R - ggplot2-based plot methods for FLCore classes
# ggplotFL/R/plot.R

# Copyright 2012-2017 FLR Team. Distributed under the GPL 2
# Maintainer: Iago Mosqueira (EC JRC) <iago.mosqueira@ec.europa.eu

# plot(FLQuant) {{{

#' ggplot versions of FLR class plot() methods
#'
#' New basic plot methods for some FLR classes are defined in ggplotFL.
#'
#' The coertion to *data.frame* that is carried out in the plot methods sets
#' the argument `date=TRUE`. This generates a new column of class `POSIXct` for
#' the first day of the first month of each season. If the `season` dimension of
#' the object being plotted is of length greater than one, `date` will be used
#' as variable on the x axis of the plot. Otherwise, it will be `year`. Keep this
#' in mind when adding extra elements to the plot (see examples below).
#' 
#' A similar mechanism is used for the *y* axis, depending on the length of the
#' `iter` dimension. For objects with no *iters*, a single line is plotted for
#' each *FLQuant*, and the *y* axis is mapped to the `data` column of the
#' *data.frame*. For objects with iterations, i.e. with length greater than 1 on
#' the `iter` dimension, the default plots show the quantiles of the distribution
#' and the *y* axis is mapped to the middle quantile, by default `50%`. See the
#' examples below on how to refer to these variables when adding elements to the
#' plot.
#'
#' @param x Variable on x axis.
#' @param y Variable on y axis.
#' @param main Title of plot.
#' @param xlab Label of x axis.
#' @param ylab Label of y axis.
#' @param na.rm Should NAs be deleted in quantile calculations?, defaults to TRUE.
#' @param probs Quantiles to be plotted if object has iters, defaults to c(0.10, 0.25, 0.50, 0.75, 0.90).
#' @param type Type of quantile calculated, see \code{\link[stats]{quantile}}. Defaults to 7.
#' @param fill Colour to be used for filling of quantile poligons, defaults to 'red'.
#' @param colour Colour to be used for last quantile lines, defaults to fill.
#' @param ... Other arguments to be passed to the corresponding ggplot call.
#' @param foo FlQuants computed from complex objects (e.g. FLStock)
#' @param iter Individual iterations to show as worm plots over the quantiles.
#'
#' @aliases plot,FLQuant,missing-method
#' @seealso \code{\link{ISOdate}}\code{\link{ggplot}} 
#' @docType methods
#' @rdname plot
#' @name ggplotFL plot methods
#' @examples
#'
#'  # Plot a single FLQuant
#'  data(ple4)
#'  plot(catch.n(ple4))
#'
#'  # Plot an FLQuant with iters, shows quantiles
#'  flq <- rnorm(100, catch(ple4), 60000)
#'  plot(flq)
#'
#'  # Specify quantiles, default is c(0.10, 0.25, 0.50, 0.75, 0.90)
#'  plot(flq, probs=c(0.05, 0.40, 0.50, 0.60, 0.95))
#'
#'  # Adding extra elements to an FLQuant plot, with seasons
#'  flq <- FLQuant(runif(200), dim=c(1,15,1,4))
#'  plot(flq) + geom_point(aes(x=date, y=data, colour=season))
#'
#' # or without them
#'  flq <- FLQuant(runif(200), dim=c(1,15))
#'  plot(flq) + geom_point(aes(x=year, y=data))
#'
#' # For an object with iter, the y axis is called `50%`
#'  flq <- rlnorm(100, flq, 0.4)
#'  plot(flq) + geom_point(aes(x=year, y=`50%`))

setMethod("plot", signature(x="FLQuant", y="missing"),
	function(x, main="", xlab="", ylab="", na.rm=TRUE,
    probs=c(0.10, 0.25, 0.50, 0.75, 0.90), type=7, iter=missing) {

		# object w/ iters? compute quantiles
		if(dims(x)$iter > 1 & !is.null(probs)) {
			
			# check probs length is odd
			if(is.integer(length(probs)/2))
				stop("quantile probs can only be a vector of odd length")
		
			quans <- paste0(probs * 100, "%")
			mid <- ceiling(length(quans)/2)
			mquan <- quans[mid]
			
			# compute quantiles on FLQs, then convert to df
		  df <- as.data.frame(quantile(x, probs=probs, na.rm=na.rm, type=type),
        date=TRUE)

      # turn to wide
      df <- reshape(df, timevar="iter", direction="wide",
        idvar=c(names(df)[1:5], "date"))
      
      names(df) <- gsub("data.", "", names(df))

		# otherwise, plot on 'data'
		} else {
			df <- as.data.frame(x, date=TRUE)
			mquan <- "data"
		}


		# dims on facet or groups
		dx <- dim(x)
		ldi <- names(x)[-c(2,3,4,6)][dx[-c(2,3,4,6)] > 1]

    # CHOOSE x axis
    if (length(levels(df$season)) == 1)
      xaxis <- 'year'
    else
      xaxis <- 'date'
		
    # basic plot data vs. date
		p <- ggplot(data=na.omit(df), aes_q(x=as.name(xaxis), y=as.name(mquan))) +
			# xlab + ylab +
			xlab(xlab) + ylab(ylab) +
			# limits to include 0 +
			expand_limits(y=0) +
			# no legend +
			theme(legend.title = element_blank()) 

    # LINE by unit
		p <- p + if(dim(x)[3] ==1) {
        geom_line(colour="black", na.rm=TRUE)}
      else {
        geom_line(aes(colour=unit), na.rm=TRUE)}

    # SHOW NAs in x axis
		if(dims(x)$iter == 1) {
      if(sum(is.na(df$data)) > 0) {
        p <- p + geom_point(aes(y=0), cex=0.6, colour='darkgrey',
          data=subset(df, is.na(data)))
      }
    }
		
		# build formula
		if(length(ldi) == 1) {
			p <- p + facet_grid(as.formula(paste0(ldi, "~.")), scales="free", 
				labeller=label_both)
		}
		else if (length(ldi) > 1) {
			p <- p + facet_grid(as.formula(paste0(ldi[1], "~", paste(ldi[-1],
				sep= "+"))), scales="free", labeller=label_both)
		}

		# object w/ iters?
		if(dims(x)$iter > 1 & !is.null(probs)) {

			p <- p +
				# extreme probs as dotted line
				geom_line(aes_q(x=as.name(xaxis), y = as.name(quans[1])),
					colour="red", alpha = .50, linetype=3, na.rm=TRUE) +
				geom_line(aes_q(x=as.name(xaxis), y = as.name(quans[length(quans)])),
					colour="red", alpha = .50, linetype=3, na.rm=TRUE)

			# all others as ribbons of changing alpha
			if(length(quans) > 3) {

				ids <- seq(2, mid-1)
				for(i in ids)
					p <- p + geom_ribbon(aes_q(x=as.name(xaxis),
						ymin = as.name(quans[i]),
						ymax = as.name(quans[length(quans)-i+1])),
						fill="red", alpha = probs[i])
			}
		}

    # plot some iters?
    if(is.numeric(iter)) {
      df <- as.data.frame(iter(x, iter), date=TRUE)
      names(df)[names(df) == "data"] <- mquan
      df$iter <- as.integer(df$iter)
      p <- p + geom_line(data=df, aes_q(x=as.name(xaxis), y=as.name(mquan),
        group=as.name("iter"), colour=as.name("iter")), na.rm=TRUE) +
        theme(legend.position="none")
    }

		return(p)
	}
) # }}}

# plot(FLQuants) {{{
#' @aliases plot,FLQuants,missing-method
#' @rdname plot
#' @examples
#'
#'  # Plot an FLQuants created from ple4 FLStock
#'  data(ple4)
#'  plot(FLQuants(SSB=ssb(ple4), rec=rec(ple4)))
#'  

setMethod("plot", signature(x="FLQuants", y="missing"),
	function(x, main="", xlab="", ylab="", probs=c(0.10, 0.25, 0.50, 0.75, 0.90),
		na.rm=TRUE, type=7, fill="red", colour="black", iter=NULL) {
    
   # check probs
    if(!length(probs) %in% c(5))
      stop("quantile 'probs' argument must be of length 5")

		# check names not repeated
		dup <- duplicated(names(x))
		if(any(dup)) {
			names(x)[dup] <- paste(names(x)[dup], LETTERS[seq(sum(dup))], sep='_')
			warning('Duplicated names in object, changed to differentiate')
		}
		
    # object w/ iters? compute quantiles
		if(any(unlist(lapply(x, function(y) dims(y)$iter)) > 1)) {
			
			# compute quantiles on FLQs, then convert to df
			df <- as.data.frame(lapply(x, quantile, probs=probs,
				na.rm=na.rm, type=type), date=TRUE)

      df <- reshape(df, timevar="iter", direction="wide",
        idvar=c(names(x[[1]])[1:5], "date", "qname"))
      
      names(df) <- gsub("data.", "", names(df))

		# otherwise
		} else {
			df <- as.data.frame(x, date=TRUE)
		}

    # CHOOSE x axis
    if (length(levels(df$season)) == 1)
      xaxis <- 'year'
    else
      xaxis <- 'date'
    
    # and y axis
    if("data" %in% names(df))
      yaxis <- "data"
    else {
      ylabs <- paste0("`", round(probs * 100), "%`")
      yaxis <- ylabs[3]
    }
    
    # plot data vs. year + facet on qname +
		p <- ggplot(data=na.omit(df),
        aes_string(x=xaxis, y=yaxis, group="unit")) +
			facet_grid(qname~., scales="free", labeller=label_flqs(x)) +
			# xlab + ylab + limits to include 0 +
      xlab(xlab) + ylab(ylab) + expand_limits(y=0) +
			# no legend
      theme(legend.position="none")

    # LINE by unit?
    uts <- unlist(lapply(x, function(x) dim(x)[3]))
		if(all(uts == 1)) {
        p <- p + geom_line(colour=colour, na.rm=na.rm)
      } else {
        p <- p + geom_line(aes(colour=unit)) # + theme(legend.position="bottom")
      }
		
    # object w/ iters?
		if(any(unlist(lapply(x, function(y) dims(y)$iter)) > 1) & !all(is.na(probs))) {
			p <- p +
			# 75% quantile ribbon in red, alpha=0.25
			geom_ribbon(aes_string(x=xaxis, ymin = ylabs[2], ymax = ylabs[4]),
				fill=fill, alpha = .25, na.rm=na.rm) +
			# 90% quantile ribbon in red, aplha=0.10
			geom_ribbon(aes_string(x=xaxis, ymin = ylabs[1], ymax = ylabs[5]),
				fill=fill, alpha = .10, na.rm=na.rm) +
			# .. and dotted lines
			geom_line(aes_string(x=xaxis, y = ylabs[1]),
				colour=colour, alpha = .50, linetype=3, na.rm=na.rm) +
			geom_line(aes_string(x=xaxis, y = ylabs[5]),
				colour=colour, alpha = .50, linetype=3, na.rm=na.rm) +
      scale_fill_manual(values=c("red"))
		}

    # plot some iters?
    if(!is.null(iter)) {
      df <- as.data.frame(iter(x, iter), date=TRUE)
      idx <- unlist(lapply(x, function(x) dims(x)$iter)) > 1
      df <- subset(df, qname == names(x)[idx])
      
      df$iter <- as.integer(df$iter)
      df$time <- df[, xaxis]

      p <- p + geom_line(data=df, aes(x=time, y=data,
        group=interaction(iter, unit), colour=interaction(iter, unit))) +
        # colours
        scale_color_manual(values=.flpalette[-1])
    }
		
		return(p)
	}
) # }}}

# plot(FLQuants, FLPar) {{{

#' @aliases plot,FLQuants,FLPar-method
#' @rdname plot
#' @examples
#'  # plot for FLQuants, FLPar
#'  data(ple4)
#'  rps <- FLPar(F=0.14, Catch=1.29e5, Rec=9.38e5, SSB=1.8e5)
#'  fqs <- metrics(ple4)
#'  plot(fqs, rps)
#'  # Works also if reptsa are given for some panels
#'  rps <- FLPar(F=0.14, Catch=1.29e5, SSB=1.8e5)
#'  plot(fqs, rps)

setMethod("plot", signature(x="FLQuants", y="FLPar"),
	function(x, y, ...) {
	
		p <- plot(x)

    # GET name variable mapped to y axis
    dat <- quo_name(p$mapping$y)
    
    # CREATE df with right name
		rpa <- data.frame(dat=c(y), qname=dimnames(y)$params, stringsAsFactors=FALSE)
    colnames(rpa)[1] <- dat

		# FIX mixmatch between refpts and FLStock slots naming
		if('yield' %in% rpa$qname)
			rpa$qname[rpa$qname == 'yield'] <- 'catch'

		p <- p + geom_hline(data=rpa, aes(yintercept=data), colour="blue", linetype=2)

		return(p)
	}
) # }}}

# plot(FLStock) {{{

#' @aliases plot,FLStock,missing-method
#' @rdname plot
#' @examples
#'
#'  # plot of an FLStock
#'  data(ple4)
#'  plot(ple4)
#'

setMethod("plot", signature(x="FLStock", y="missing"),
	function(x, colour=c("#8da0cb","#fc8d62", "#66c2a5"), ...) {
 
    mets <- metrics(x)
  
    # ADAPT for 2-sex model
    if(all(dimnames(mets$SSB)$unit %in% c("F", "M"))) {

      # DROP M ssb if missing
      mets$SSB <- mets$SSB[,,'F'] + mets$SSB[,,'M']

      # SUM rec across units
      mets$Rec <- unitSums(mets$Rec)
    }

    # ADAPT for seasonal recruitment
    if(dim(mets$Rec)[4] > 1) {
      mets$Rec[mets$Rec == 0] <- NA 
    }

    p <- plot(mets, ...)
  
    # ADD legend if 2 sexes  
    if(all(dimnames(mets$SSB)$unit %in% c("F", "M"))) {
      return(p +
        theme(legend.position="bottom", legend.key=element_blank()) +
        labs(color="Sex") +
        scale_color_manual(name="Gender",
          labels=c("Both", "F", "M"),
          values=c("unique"=colour[1], "F"=colour[2], "M"=colour[3]))
      )
    }

		return(p)
	}
) # }}}

# plot(FLStock, FLStock) {{{

#' @aliases plot,FLStock,FLStock-method
#' @rdname plot

setMethod("plot", signature(x="FLStock", y="FLStock"),
	function(x, y, main="", xlab="", ylab="", ..., iter=NULL) {

    args <- list(...)

    sts <- do.call("FLStocks", c(list(x, y), args))

    names(sts) <- unlist(lapply(sts, name))

    p <- plot(sts, iter=NULL)

		return(p)
	}
) # }}}

# plot(FLStock, FLPar) {{{
#' @aliases plot,FLStock,FLPar-method
#' @rdname plot
#' @examples
#'
#'  # plot for FLStock, FLPar
#'  data(ple4)
#'  rps <- FLPar(Harvest=0.14, Catch=1.29e5, Rec=9.38e5, SSB=1.8e5)
#'  plot(ple4, rps)
#'  

setMethod("plot", signature(x="FLStock", y="FLPar"),
	function(x, y, ...) {
	
    p <- plot(metrics(x), y)

    return(p)
	}
) # }}}

# plot(FLStocks) {{{

#' @aliases plot,FLStocks,missing-method
#' @rdname plot
#' @param metrics function returning an FLQuants for each FLStock
#' @examples
#'
#'  # plot for FLStocks
#'  data(ple4)
#'  pls <- FLStocks(runA=ple4, runB=qapply(ple4, function(x) x*1.10))
#'  plot(pls)
#'  

setMethod("plot", signature(x="FLStocks", y="missing"),
	function(x, main="", xlab="", ylab="", na.rm=TRUE,
		metrics=function(y) FLQuants(Rec=rec(y), SSB=ssb(y), Catch=catch(y), Harvest=fbar(y)), ...) {
	
		# check names not repeated
		dup <- duplicated(names(x))
		if(any(dup)) {
			names(x)[dup] <- paste(names(x)[dup], LETTERS[seq(sum(dup))], sep='_')
			warning('Duplicated names in object, changed to differentiate')
		}
		
		# extract slots by stock
		fqs <- lapply(x, metrics)

    # get labels
    labeller <- label_flqs(fqs[[1]])

		# get median & 85% quantiles if iters
		its <- unlist(lapply(x, function(x) dims(x)$iter))
		if(any(its > 1))
		{
			# quantiles
			fqs <- lapply(fqs, function(y) as.data.frame(lapply(y, quantile,
				c(0.10, 0.50, 0.90), na.rm=TRUE), date=TRUE))
		} else {
			fqs <- lapply(fqs, as.data.frame, date=TRUE)
			fqs <- lapply(fqs, function(x) {x$iter <- "50%"; return(x)})
		}

		# stock names
		stk <- rep.int(names(fqs), unlist(lapply(fqs, nrow)))
		# rbind dfs
		fqs <- do.call(rbind, fqs)
		rownames(fqs) <- NULL
		# add stock names
		fqs <- transform(fqs, stock=stk)

    # compute quantiles
    df <- reshape(fqs, timevar="iter", direction="wide",
      idvar=c(names(fqs)[1:5], "qname", "stock", "date"))
      
    names(df) <- gsub("data.", "", names(df))

		# plot data vs. date + facet on qname +
		p <- ggplot(data=na.omit(df), aes_string(x='`date`', y='`50%`', group='stock')) +
			facet_grid(qname~., scales="free", labeller=labeller) +
			# line + xlab + ylab +
			geom_line(aes(colour=stock), na.rm=na.rm) + xlab(xlab) + ylab(ylab) +
			# limits to include 0 +  no legend
			expand_limits(y=0) + theme(legend.title = element_blank())
		
		# object w/ iters?
		if(any(unlist(lapply(x, function(y) dims(y)$iter)) > 1)) {
				p <- p +
			# 75% quantile ribbon in red, alpha=0.25
			geom_ribbon(aes_string(x='date', ymin = '`10%`', ymax = '`90%`', group='stock',
				colour='stock', fill='stock'), alpha = .20, linetype = 0, na.rm=na.rm)
			# 90% quantile ribbon in red, aplha=0.10
		}
		return(p)
	}
) # }}}

# plot(FLStocks, FLPar) {{{
#' @aliases plot,FLStocks,FLPar-method
#' @rdname plot
#' @examples
#'
#'  # plot for FLStocks
#'  data(ple4)
#'  pls <- FLStocks(runA=ple4, runB=qapply(ple4, function(x) x*1.10))
#'  plot(pls)
#'  

setMethod("plot", signature(x="FLStocks", y="FLPar"),
	function(x, y, main="", xlab="", ylab="", na.rm=TRUE,
		foo= function(x, y) FLQuants(SSB=ssb(x)/y[,'ssb',], F=fbar(x)/y[,'harvest',],
			Catch=catch(x))) {
		
		# check names not repeated
		dup <- duplicated(names(x))
		if(any(dup)) {
			names(x)[dup] <- paste(names(x)[dup], LETTERS[seq(sum(dup))], sep='_')
			warning('Duplicated names in object, changed to differentiate')
		}
		
		# extract slots by stock
		fqs <- lapply(x, foo, y)

		# get median & 85% quantiles if iters
		its <- unlist(lapply(x, function(x) dims(x)$iter))
		if(any(its > 1))
		{
			# quantiles
			fqs <- lapply(fqs, function(y) as.data.frame(lapply(y, quantile,
				c(0.10, 0.50, 0.90), na.rm=TRUE)))
		} else {
			fqs <- lapply(fqs, as.data.frame)
			fqs <- lapply(fqs, function(x) {x$iter <- "50%"; return(x)})
		}

		# stock names
		stk <- rep.int(names(fqs), unlist(lapply(fqs, nrow)))
		# rbind dfs
		fqs <- do.call(rbind, fqs)
		rownames(fqs) <- NULL
		# add stock names
		fqs <- transform(fqs, stock=stk)

    # compute quantiles
    df <- reshape(fqs, timevar="iter", direction="wide",
      idvar=c(names(fqs)[1:5], "qname", "stock", "date"))
      
    names(df) <- gsub("data.", "", names(df))

		# plot data vs. date + facet on qname +
		p <- ggplot(data=na.omit(df), aes_string(x='date', y='`50%`', group='stock')) +
			facet_grid(qname~., scales="free") +
			# line + xlab + ylab +
			geom_line(aes_string(colour='stock'), na.rm=na.rm) + xlab(xlab) + ylab(ylab) +
			# limits to include 0 +  no legend
			expand_limits(y=0) + theme(legend.title = element_blank())
		
    # object w/ iters?
		if(any(unlist(lapply(x, function(y) dims(y)$iter)) > 1)) {
				p <- p +
			# 75% quantile ribbon in red, alpha=0.25
			geom_ribbon(aes_string(x='date', ymin = '`10%`', ymax = '`90%`', group='stock',
				colour='stock', fill='stock'), alpha = .20, linetype = 0, na.rm=na.rm)
			# 90% quantile ribbon in red, aplha=0.10
		}
		return(p)
	}
) # }}}

# plot(FLStock, FLStocks) {{{

#' @aliases plot,FLStock,FLStocks,missing-method
#' @rdname plot

setMethod("plot", signature(x="FLStock", y="FLStocks"),
	function(x, y, ...) {
    
    plot(FLStocks(c(x, y)))
    
	}
) # }}}

# plot(FLSR) {{{
#' @aliases plot,FLSR,missing-method
#' @docType methods
#' @rdname plot
#' @examples
#'
#'  # plot for FLSR
#'  data(nsher)
#'  plot(nsher)
#'  

setMethod('plot', signature(x='FLSR', y='missing'),
	function(x, ...) {

	dat <- model.frame(FLQuants(SSB=ssb(x), Rec=rec(x), Residuals=residuals(x),
		RecHat=fitted(x)))

	uns <- units(x)
  
  unr <- ifelse(uns$rec == 'NA', 'Recruits', as.expression(paste0('Recruits (',
		sub('*', 'A', uns$rec, fixed=TRUE), ')')))
	uns <- ifelse(uns$ssb == 'NA', 'SSB', as.expression(paste0('SSB (', sub('*',
		'%*%', uns$ssb, fixed=TRUE), ')')))

	# SSB vs. REC
	p1 <- ggplot(data=na.omit(dat), aes_string(x='SSB', y='Rec')) + geom_point() +
		geom_smooth(method='loess', span=3) + xlab(uns) + ylab(unr) +
		expand_limits(y=0) + expand_limits(x=0)

	# model fit line
	form <- as.list(model(x))[[3]]
	pars <- as(params(x), 'list')

	fmo <- function(x) {
		c(eval(form, c(list(ssb=FLQuant(x)), pars)))
  }
	
	p1 <- p1 + stat_function(fun=fmo,  colour='red', size=0.5)
	
	# P2
	p2 <- ggplot(data=na.omit(dat), aes_string(x='year', y='Residuals')) +
    geom_point() + geom_smooth(method='loess', span=3) + xlab("Year")

	# P3
	p3 <- ggplot(data=na.omit(data.frame(res1=dat$Residuals[-length(dat$Residuals)],
		res2=dat$Residuals[-1])), aes_string(x='res1', y='res2')) + geom_point() +
		xlab(expression(Residuals[t])) + ylab(expression(Residuals[t + 1])) +
	  geom_smooth(method='lm')

	# P4
	p4 <- ggplot(data=na.omit(dat), aes_string(x='SSB', y='Residuals')) +
    geom_point() + geom_smooth(method='loess', span=3)

	# P5
	p5 <- ggplot(data=na.omit(dat), aes_string(sample = 'Residuals')) +
    stat_qq(color="red", alpha=1) +
    geom_abline(aes_q(intercept = quote(mean(Residuals)),
		slope = quote(sd(Residuals)))) + xlab("Theoretical") + ylab("Sample")

	# P6
	p6 <- ggplot(data=na.omit(dat), aes_string(x='RecHat', y='Residuals')) +
    geom_point() + geom_smooth(method='loess', span=3) +
    xlab(expression(hat(Recruits)))
	

	# BUG Does not return a ggplot, but a grob
	invisible(grid.arrange(p1, p2, p3, p4, p5, p6, ncol=2))

#	p <- gridExtra::arrangeGrob(p1, p2, p3, p4, p5, p6, ncol=2)
	
#	return(p)
	}
) # }}}

# plot(FLSRs) {{{

#' @aliases plot,FLSRs,missing-method
#' @docType methods
#' @rdname plot
#' @param legend_label function to create the legend labels
#' @examples
#'
#'  # plot for FLSRs
#'  data(nsher)
#'  srs <- FLSRs(sapply(c('ricker', 'bevholt'), function(x) {
#'    y <- nsher
#'    model(y) <- x
#'    return(fmle(y))
#'  }))
#'  plot(srs)
#'  
#'  plot(srs, legend_label=modlabel)
#'

setMethod("plot", signature(x="FLSRs"),
  function(x, legend_label=eqlabel, ...) {

    uns <- units(x[[1]])

    # DIFFERENT data?
    if(all(unlist(lapply(x[-1],
      function(y) isTRUE(all.equal(rec(y), rec(x[[1]])))))))
      dat <- cbind(sr=NA, model.frame(FLQuants(ssb=ssb(x[[1]]), rec=rec(x[[1]]))))
    else
      dat <- Reduce(rbind, Map(function(x, i)
        cbind(sr=i, model.frame(FLQuants(ssb=ssb(x), rec=rec(x)), drop=TRUE)),
        x, names(x)))
    
    # EXTRACT models & pars
    mods <- lapply(x, 'model')
    pars <- lapply(x, 'params')
    inp <- data.frame(ssb=seq(0, max(dat$ssb), length=100), rec=NA)

    # RESULTS
    res <- lapply(names(mods), function(x) {
      data.frame(sr=x, ssb=inp$ssb,
        rec=eval(as.list(mods[[x]])[[3]], c(list(ssb=inp$ssb), as(pars[[x]], 'list')))
        )
    })

    res <- Reduce('rbind', res)

    # GET plot
    p <- ggplot(na.omit(res), aes(x=ssb, y=rec, colour=sr)) +
      geom_line(aes(group=sr, color=sr)) +
      geom_point(data=dat) + 
      xlab(as.expression(paste0("SSB (", sub('\\*', '%.%', uns$ssb), ")"))) +
      ylab(as.expression(paste0("Recruits (", sub('\\*', '%.%', uns$rec), ")"))) +
      scale_color_discrete(name="", breaks=names(x),
        labels=do.call(legend_label, list(model=mods, param=pars))) +
      theme(legend.position="bottom") +
      guides(color=guide_legend(nrow=length(mods), byrow=TRUE))
 
    return(p)
  }

) # }}}

# plot(FLBiol) {{{

# rec, tsb, 

# }}}

# plot(FLIndexBiomass) {{{

#' @aliases plot,FLIndexBiomass,missing-method
#' @docType methods
#' @rdname plot
setMethod("plot", signature(x="FLIndexBiomass", y="missing"),
  function(x, ...) {

    flqs <- FLQuants(Index=index(x))
    ggplot(na.omit(as.data.frame(flqs, date=TRUE)), aes(x=date, y=data)) +
      geom_line() + geom_smooth(na.rm=TRUE, method="loess") +
      facet_grid(qname~.) + xlab("") + ylab("")

  }
) # }}}
