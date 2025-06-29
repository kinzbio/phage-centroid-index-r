#! /usr/bin/env Rscript

#' Reads OD measurments from infitek plate 
read_od <- function(file = "od_curve.csv"){

    if (!suppressPackageStartupMessages(require(tools))) stop("Requires tools package:\n\ninstall.packages('tools')")
    if (!suppressPackageStartupMessages(require(readr))) stop("Requires tools package:\n\ninstall.packages('tools')")
    
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
            x <- suppressWarnings(readr::read_tsv(file, skip = 19, show_col_types = FALSE, skip_empty_rows = T))
        }else{
            x <- suppressWarnings(readr::read_csv(file, skip = 19, show_col_types = FALSE, skip_empty_rows = T))
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

format_od <- function(x, time = "Time", test = c("Test"), control = "Blank", time_i, time_f) {


    if (!suppressPackageStartupMessages(require(magrittr))) stop("Requires magrittr package:\n\ninstall.packages('magrittr')")
    if (!suppressPackageStartupMessages(require(dplyr))) stop("Requires dplyr package:\n\ninstall.packages('dplyr')")

    difftime <- diff(x[[time]])
    tunits <- attr(difftime, "units")

    x %<>%
        dplyr::mutate(eval_time = Time >= time_i & Time <= time_f)

    x$time <- cumsum(as.integer(c(0, difftime)))

    x <- x[c("time", "eval_time", control, test)]

    attr(x, "time") <- "time"
    attr(x, "time_unit") <- tunits
    attr(x, "control") <- control
    attr(x, "test") <- test
    return(x)

}


compute_trapezoids <- function(x, od_col = "Test"){

    time_col <- attr(x, "time")
    trapezoids <- list()
    eval_trp <- vector(mode = "logical", length = dim(x)[1]-1)
    i <- 2
    A <- c(x[[time_col]][i - 1], 0)
    for (i in 2:nrow(x)){
        B <- c(x[[time_col]][i], 0)
        C <- c(x[[time_col]][i], x[[od_col]][i])
        D <- c(x[[time_col]][i-1], x[[od_col]][i-1])
        # E <- A
        mat <- matrix(c(A, B, C, D), ncol = 2, byrow = TRUE)
        trapezoids[[i-1]] <- mat
        eval_trp[i-1] <- x[["eval_time"]][i-1] & x[["eval_time"]][i]
        A <- B
    }
    names(trapezoids) <- seq_along(trapezoids)
    
    attr(trapezoids, "eval_trapezoid") <- eval_trp
    return(trapezoids)

}

centroid_xy_area <- function(vertices) {
    # vertices: a two-column matrix or data.frame (x, y)
    # Each row is a vertex. The vertices must be in order (clockwise or counterclockwise)
    n <- nrow(vertices)
    x <- vertices[, 1]
    y <- vertices[, 2]  
    
    # Close trapezoid (E == A)
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

    if (!suppressPackageStartupMessages(require(optparse)))  stop("Requires optparse package:\n\ninstall.packages('optparse')")
    if (!suppressPackageStartupMessages(require(ggplot2)))   stop("Requires ggplot2 package:\n\ninstall.packages('ggplot2')")
    if (!suppressPackageStartupMessages(require(magrittr)))  stop("Requires magrittr package:\n\ninstall.packages('magrittr')")
    if (!suppressPackageStartupMessages(require(dplyr)))     stop("Requires dplyr package:\n\ninstall.packages('dplyr')")
    if (!suppressPackageStartupMessages(require(tidyr)))     stop("Requires tidyr package:\n\ninstall.packages('tidyr')")

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
        help = "The name of the control column."
    )

    parser <- add_option(
        parser,
        c("-e", "--eval_columns"),
        action = "store",
        type = "character",
        help = 'The name of the column to evaluate. Can be more than one, should be passed separated by comma and quoted: "B4,B5,B6".'
    )

    parser <- add_option(
        parser,
        c("-p", "--plot"),
        action = "store",
        type = "character",
        default = "",
        help = 'If provided, the name to the plot file (png). Default: ""'
    )

    parser <- add_option(
        parser,
        c("-s", "--starting_time"),
        action = "store",
        type = "character",
        default = "0:00:00",
        help = 'If provided, the initial time to consider, in the format "H:MM:SS". Default: "0:00:00".'
    )

    parser <- add_option(
        parser,
        c("-f", "--final_time"),
        action = "store",
        type = "character",
        default = "Inf",
        help = 'If provided, the final time to consider, in the format "H:MM:SS", or Inf. Default: "Inf".'
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
    plot <- opt$plot
    tini <- opt$starting_time
    tfin <- tolower(opt$final_time)

    # Check inputs
    if (!length(input)) stop("Missing --input argument. Provide an input csv file.")
    if (!file.exists(input)) stop(paste("Input file", input, "doesn't exists."))
    if (!length(time_col)) stop("Missing --time_column argument. Provide the name of the Time column.")
    if (!length(control_col)) stop("Missing --control_column argument. Provide the name of the Control column.")
    if (!length(eval_cols)) stop("Missing --eval_columns argument. Provide the name of the columns to evaluate, separated by comma if multiple.")


    # Check initial and final times
    time_i <- as.POSIXct(paste("1899-12-31", tini), format = "%Y-%m-%d %H:%M:%S", tz = "UTC")
    if (is.na(time_i)) stop('Argument --initial_time has wrong format. Should be like "0:10:00" (starts at minute 10).')
    if (tfin != "inf"){
        time_f <- as.POSIXct(paste("1899-12-31", tfin), format = "%Y-%m-%d %H:%M:%S", tz = "UTC")
    } else {
        time_f <- as.POSIXct(Inf, tz = "UTC")
    }
    if (is.na(time_f)) stop('Argument --final_time has wrong format. Should be like "1:10:00" (ends at minute 70), or "Inf".')

    # Make vector of columns to evaluate
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

    fod <- format_od(od, time = time_col, test = evals, control = control_col, time_i = time_i, time_f = time_f)

    # Computes trapezoids, then their centroids and areas.
    tcas <- mapply(
        FUN = function(fod, od_col) {
            trps <- compute_trapezoids(fod, od_col = od_col)
            eval_trps <- attr(trps, "eval_trapezoid")
            mp <- mapply(FUN = function(trp, index, eval){
                ca <- centroid_xy_area(trp)
                data.frame(
                    ID = od_col,
                    index = index,
                    Ax = trp[1, 1],
                    Ay = trp[1, 2],
                    Bx = trp[2, 1], 
                    By = trp[2, 2],
                    Cx = trp[3, 1],
                    Cy = trp[3, 2],
                    Dx = trp[4, 1],
                    Dy = trp[4, 2], 
                    Centroid_x = ca[["Cx"]],
                    Centroid_y = ca[["Cy"]],
                    Area = ca[["Area"]],
                    Eval = eval
                )
                }, 
                trp = trps, index = names(trps), eval = eval_trps, SIMPLIFY = FALSE
            )
            do.call(rbind, mp)
        },
        od_col = c(control_col, evals),
        MoreArgs = list(fod = fod),
        SIMPLIFY = FALSE
    )

    polys <- tcas %>%
        do.call(rbind, .) %>%
        dplyr::group_by(ID, index) %>%
        dplyr::reframe(
            X = c(Ax, Bx, Cx, Dx, Ax),
            Y = c(Ay, By, Cy, Dy, Ay),
            Centroid_X = Centroid_x, 
            Centroid_Y = Centroid_y,
            Area = Area, 
            Eval = Eval
        )

    curve_centroids <- polys %>%
        dplyr::filter(Eval) %>%
        dplyr::group_by(ID, index) %>%
        dplyr::reframe(
            Centroid_X = unique(Centroid_X),
            Centroid_Y = unique(Centroid_Y),
            Area = unique(Area)
        ) %>%
        dplyr::group_by(ID) %>%
        dplyr::reframe(
            Curve_Centroid_X = sum(Centroid_X * Area) / sum(Area),
            Curve_Centroid_Y = sum(Centroid_Y * Area) / sum(Area)
        ) 


    if (plot != "") {

            gg <- ggplot(polys, aes(x = X, y = Y, color = ID)) +
                geom_path(mapping = aes(alpha = Eval)) +
                scale_alpha_manual(values = c("TRUE" = .9, "FALSE" = 0.2)) +
                geom_point(
                    data = curve_centroids, 
                    mapping = aes(x = Curve_Centroid_X, y = Curve_Centroid_Y, color = ID),
                    size = 5
                ) +
                ylab("OD") + xlab("Time (min)") +
                theme_classic() 

            ggsave(plot = gg, filename = paste(plot, ".png", sep = ""), height = 7, width = 10)

    }

    control_centroid <- curve_centroids %>% dplyr::filter(ID == control_col)
    evals_centroids <- curve_centroids %>% dplyr::filter(ID != control_col)

    CIs <- evals_centroids %>%
        dplyr::group_by(ID) %>%
        dplyr::reframe(
            CI = 1 - ((
                Curve_Centroid_X * Curve_Centroid_Y
            ) / (
                control_centroid$Curve_Centroid_X * control_centroid$Curve_Centroid_Y
            ))
        )
    
    write.table(CIs, sep = "\t", file = stdout(), row.names = F, quote = F)
    return(invisible(NULL))
}

main()