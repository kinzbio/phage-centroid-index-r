# phage-centroid-index-r
An R implementation of [Hosseini's (2024)](https://www.nature.com/articles/s42003-024-06379-z) Centroid Index metric for assessing phage growth efficiency.

This repo contains a single executable script, which can be run from the terminal, and an example dataset. It is not an R package, although it could be in the future.

## Important
The script assumes the `csv` file has the same layout as returned by the Infitek's® spectrophotometer we have at Kinzbio. Should be easy to adapt to your own need. 

## Usage
To use the script, you should make it executable first: `chmod +x centroid_index.r`, and met [dependencies](#dependencies).
```
Usage
=====
 ./centroid_index.r [options]


Options
=======
--help, -h
                Show this help message and exit

--input=INPUT, -i INPUT
                Path to csv file with OD measurements. Assumes Infitek's spectrophotometer output layout.

--time_column=TIME_COLUMN, -t TIME_COLUMN
                The name of the time column.

--control_column=CONTROL_COLUMN, -c CONTROL_COLUMN
                The name of the control column.

--eval_columns=EVAL_COLUMNS, -e EVAL_COLUMNS
                The name of the column to evaluate. Can be more than one, should be passed separated by comma and quoted: "B4,B5,B6".

--plot=PLOT, -p PLOT
                If provided, the name to the plot file (png). If not provided, the plotting is avoided.

--starting_time=STARTING_TIME, -s STARTING_TIME
                If provided, the initial time to consider, in the format "H:MM:SS". Default: "0:00:00".

--final_time=FINAL_TIME, -f FINAL_TIME
                If provided, the final time to consider, in the format "H:MM:SS", or Inf. Default: "Inf".
```
# Example
This repo comes with a `csv` file example, for testing and for if you need to replicate the format. 

```
./centroid_index.r \
    --input ./inst/extdata/exampleOD.csv \
    --time_column "Time" \
    --control_column "C10" \
    --eval_columns "C4,C5,C6,C7,C8" \
    --plot "start7hs" \
    --starting_time "07:00:00"
```
Result (printed in console):
```
ID    CI
C4    0.422265123214789
C5    0.258525277242484
C6    0.425114894335908
C7    0.403943308542125
C8    0.478949149585175
```
And since we set the flag `--starting_time "07:00:00"`, the program only considers OD measures starting at that time for computing the centroids and the CI.

The resulting plot showing the trapezoids and the centroids is the following:

![trapezoids and centroids](/inst/extdata/start7hs.png){width=500}

The trapezoids occurring before the starting time are shaded.

# Dependencies
Requires the following R packages to be installed:
 * tools (If you have R installed, you probably already have it already)
 * optparse (In the R console: `install.packages('optparse')`)
 * magrittr (In the R console: `install.packages('magrittr')`)
 * tidyr (In the R console: `install.packages('tidyr')`)
 * dplyr (In the R console: `install.packages('dplyr')`)
 * ggplot2 (In the R console: `install.packages('ggplot2')`)

# Citation
Please cite Hosseini's article:
```
Hosseini, N., Chehreghani, M., Moineau, S. et al. Centroid of the bacterial growth curves: a metric to assess phage efficiency. Commun Biol 7, 673 (2024). https://doi.org/10.1038/s42003-024-06379-z
```
