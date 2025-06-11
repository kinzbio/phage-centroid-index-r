# phage-centroid-index-r
An R implementation of [Hosseini's (2024)](https://www.nature.com/articles/s42003-024-06379-z) Centroid Index metric for assessing phage growth efficiency.

This repo contains a single script, which can be executed from the terminal, and an example dataset. It is not an R package, although it could be in the future.

## Important
The script assumes the `csv` file has the same layout as returned by the Infitek's® spectrophotometer we have in Kinzbio. Should be easy to adapt to your own need. 

## Usage
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
```
# Example
This repo comes with a `csv` file example, for testing and for if you need to replicate the format. 

```
./centroid_index.r \
    --input ./inst/extdata/exampleOD.csv \
    --time_column "Time" \
    --control_column "C10" \
    --eval_columns "C4,C5,C6,C7,C8"
```
Result (printed in console):
```
Name    Centroid_Index
C4      0.425946356973334
C5      0.265642221211866
C6      0.430014992809797
C7      0.413032018605875
C8      0.47985976983021
```

# Dependencies
Requires the following R packages to be installed:
 * tools (If you have R installed, you probably already have it already)
 * optparse (In the R console: `install.packages('optparse')`)

# Citation
Please cite Hosseini's article:
```
Hosseini, N., Chehreghani, M., Moineau, S. et al. Centroid of the bacterial growth curves: a metric to assess phage efficiency. Commun Biol 7, 673 (2024). https://doi.org/10.1038/s42003-024-06379-z
```
