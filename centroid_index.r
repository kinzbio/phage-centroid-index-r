#! /usr/bin/env Rscript

#' Reads OD measurments from infitek plate 
read_od <- function(file = "od_curve.csv"){

    if (!suppressPackageStartupMessages(require(tools))) stop("Requires tools package:\n\ninstall.packages('tools')")
    
    ext <- tolower(tools::file_ext(file))
    if (ext %in% c("tsv", "csv")){
        # Check integrity of infitek's spectrophotometer output file.
        rl <- readLines(con = file, warn = FALSE)[1:19]
        stopifnot(
            "The file doesn't looks as expected: first cell should contain 'Protocol Name:'" = grepl("^Protocol Name:", rl[1]),
            "The file doesn't looks as expected: second cell should contain 'Experiment Created:'" = grepl("^Experiment Created:", rl[2]),
            "The file doesn't looks as expected: the 15th cell should contain 'Incubation:'" = grepl("^Incubation:", rl[15]),
            "The file doesn't looks as expected: the 17th cell should contain 'Incubation_Temp:'" = grepl("^Incubation_Temp:", rl[17])
        )
        # Reads csv
        if (ext == "tsv"){
            x <- suppressWarnings(read.csv(file, sep = "\t", header = TRUE, skip = 19, skipNul = TRUE))
        }else{
            x <- suppressWarnings(read.csv(file, sep = ",", header = TRUE, skip = 19, skipNul = TRUE))
        }
        x <- x[!sapply(x, function(y) all(is.na(y)))] # Removes NA columns
        x <- x[!is.na(x$No.), ]
        # x <- tibble::tibble(x)
        x$Time <- as.POSIXct(
            x = paste("1899-12-31", x$Time, sep = " "),
            format = "%Y-%m-%d %H:%M:%S", 
            tz = "UTC"
        )
    }else if(grepl("xls", ext)){
        stop("Reading excel files is buggy. Please, export and pass Infitek's csv/tsv output file as argument.")
        x <- readxl::read_excel(file)
    }
    return(x)

}

format_od <- function(x, time = "Time", test = c("Test"), control = "Blank") {

    difftime <- diff(x[[time]])
    tunits <- attr(difftime, "units")

    x$time <- cumsum(as.integer(c(0, difftime)))

    x <- x[c("time", control, test)]

    attr(x, "time") <- "time"
    attr(x, "time_unit") <- tunits
    attr(x, "control") <- control
    attr(x, "test") <- test
    return(x)

}


compute_trapezoids <- function(x, od_col = "Test"){

    time_col <- attr(x, "time")
    trapezoids <- list()
    i <- 2
    A <- c(x[[time_col]][i - 1], 0)
    for (i in 2:nrow(x)){
        B <- c(x[[time_col]][i], 0)
        C <- c(x[[time_col]][i], x[[od_col]][i])
        D <- c(x[[time_col]][i-1], x[[od_col]][i-1])
        E <- A
        mat <- matrix(c(A, B, C, D, E), ncol = 2, byrow = TRUE)
        trapezoids[[i-1]] <- mat
        A <- B
    }
    names(trapezoids) <- seq_along(trapezoids)

    return(trapezoids)

}

centroid_xy_area <- function(vertices) {
    # vertices: a two-column matrix or data.frame (x, y)
    # Each row is a vertex. The vertices must be in order (clockwise or counterclockwise)
    n <- nrow(vertices)
    x <- vertices[, 1]
    y <- vertices[, 2]  
    
    # 
    x_ext <- c(x, x[1])
    y_ext <- c(y, y[1]) 
    
    # 2 * Area
    doble_area <- sum(x * y_ext[2:(n + 1)]) - sum(x_ext[2:(n + 1)] * y) 
    
    # Area
    area <- doble_area / 2  
    if (area == 0) {
        stop("Trapezoid's area is 0. Can't compute the centroid.")
    }   
    
    # Computes Cx
    cx_num <- sum((x + x_ext[2:(n + 1)]) * (x * y_ext[2:(n + 1)] - x_ext[2:(n + 1)] * y))
    Cx <- cx_num / (3 * doble_area) 
    
    # Computes Cy
    cy_num <- sum((y + y_ext[2:(n + 1)]) * (x * y_ext[2:(n + 1)] - x_ext[2:(n + 1)] * y))
    Cy <- cy_num / (3 * doble_area)   
    return(c(Cx = Cx, Cy = Cy, Area = area))
}


main <- function(){

    if (!suppressPackageStartupMessages(require(optparse))) stop("Requires optparse package:\n\ninstall.packages('optparse')")

    parser <- OptionParser(formatter = TitledHelpFormatter)

    parser <- add_option(
        parser,
        c("-i", "--input"),
        action = "store",
        type = "character",
        help = "Path to csv file with OD measurements. Assumes Infitek's spectrophotometer output layout."
    )

    parser <- add_option(
        parser,
        c("-t", "--time_column"),
        action = "store",
        type = "character",
        default = "Time",
        help = "The name of the time column."
    )

    parser <- add_option(
        parser,
        c("-c", "--control_column"),
        action = "store",
        type = "character",
        default = "Time",
        help = "The name of the control column."
    )

    parser <- add_option(
        parser,
        c("-e", "--eval_columns"),
        action = "store",
        type = "character",
        default = "Time",
        help = 'The name of the column to evaluate. Can be more than one, should be passed separated by comma and quoted: "B4,B5,B6".'
    )

    if (length(commandArgs(TRUE)) == 0) {
        print_help(parser)
        quit(status = 0)
    }

    opt <- parse_args(parser)

    # Load inputs
    input <- opt$input
    time_col <- opt$time_column
    control_col <- opt$control_column
    eval_cols <- opt$eval_columns

    evals <- strsplit(eval_cols, ",")[[1]]

    # Read OD table
    od <- read_od(input)
    od_cols <- colnames(od)

    # Check if queried columns exists
    evals_cols <- evals %in% od_cols
    if (!any(evals_cols)) {
        n_evals_cols <- paste(evals[!evals_cols], collapse = " ")
        stop(paste("The following requested columns do not exist in the OD table:", n_evals_cols))
    }

    # Check if control column exists
    if (!control_col %in% od_cols) {
        stop(paste("The control column '", control_col, "' does not exits in the OD table.", sep = ""))
    }

    # Check if time column exists
    if (!time_col %in% od_cols) {
        stop(paste("The time column '", time_col, "' does not exits in the OD table.", sep = ""))
    }

    fod <- format_od(od, time = time_col, test = evals, control = control_col)

    # Computes trapezoids, then their centroids and areas.
    tcas <- mapply(
        FUN = function(fod, od_col) {
            trps <- compute_trapezoids(fod, od_col = od_col)
            mp <- mapply(FUN = function(trp, index){
                ca <- centroid_xy_area(trp)
                data.frame(
                    ID = od_col,
                    index = index,
                    Cx = ca[["Cx"]],
                    Cy = ca[["Cy"]],
                    Area = ca[["Area"]]
                )
                }, 
                trp = trps, index = names(trps), SIMPLIFY = FALSE
            )
            do.call(rbind, mp)
        },
        od_col = c(control_col, evals),
        MoreArgs = list(fod = fod),
        SIMPLIFY = FALSE
    )

    # Compute centroids for the whole curves
    whole_centroids <- lapply(tcas, function(y){
        x_curve <- sum(y$Cx * y$Area) / sum(y$Area)
        y_curve <- sum(y$Cy * y$Area) / sum(y$Area)
        ID <- unique(y$ID)
        c(
            Cx = x_curve,
            Cy = y_curve
        )
    })

    control_centroid <- whole_centroids[[control_col]]
    evals_centroids <- whole_centroids[!grepl(control_col, names(whole_centroids))]

    # Compute Centroid Index CI
    CIs <- sapply(evals_centroids, function(y){
        1 - ((
            y[["Cx"]] * y[["Cy"]]
        ) / (
            control_centroid[["Cx"]] * control_centroid[["Cy"]]
        ))
    })

    cat("Name\tCentroid_Index", sep = "\n")
    cat(paste(names(CIs), CIs, sep = "\t"), sep = "\n")
    return(invisible(NULL))
}

main()