```@meta
CurrentModule = ClimateTools
```

# Visualization

## Maps

Mapping a `ClimGrid` is done by using the [`mapclimgrid`](@ref) function.

```julia
C = load(filenc, "pr", data_units="mm")
mapclimgrid(C)
```

![CanESM2](assets/CanESM2.png)

```@docs
mapclimgrid
```

Note that the function plots the climatological mean of the provided `ClimGrid`. Multiple options are available for region: `World`, `Canada`, `Quebec`, `WorldAz`, `WorldEck4`, ..., and the default `auto` which use the maximum and minimum of the lat-long coordinates inside the `ClimGrid` structure (see the documentation of `mapclimgrid` for all region options).

The user can also provide a polygon(s) and the `mapclimgrid` function will clip the grid points outside the specified polygon. Another option is to provide a mask (with dimensions identical to the spatial dimension of the `ClimGrid` data) which contains `NaN` and `1.0` and the data inside the `ClimGrid` struct will be clipped with the mask.


## Timeseries

Plotting timeseries of a given `ClimGrid` C is simply done by calling [`plot`](@ref). This returns the spatial average throughout the time dimension.

```julia
using ClimateTools
poly_reg = [[NaN -65 -80 -80 -65 -65];[NaN 42 42 52 52 42]]
# Extract tasmax variable over specified polygon, between January 1st 1950 and December 31st 2005
C_hist = load("historical.nc", "tasmax", data_units="Celsius", poly=poly_reg, start_date=Date(1950, 01, 01), end_date=Date(2005, 12, 31)))
# Extract tasmax variable over specified polygon, between January 1st 2006 and December 31st 2090 for emission scenario RCP8.5
C_future85 = load("futureRCP85.nc", "tasmax", data_units="Celsius", poly=poly_reg, start_date=Date(2006, 01, 01), end_date=Date(2090, 12, 31)))
C = merge(C_hist, C_future)
ind = annualmax(C) # compute annual maximum
plot(ind)
```

![annualmaxtasmax](assets/timeserie_uqam_crcm5.png)

*Note. Time labels ticks should be improved!*

The timeserie represent the spatial average of the annual maximum temperature over the following region.

```julia
mapclimgrid(ind, region = "QuebecNSP")
```

![annualmaxtasmax_maps](assets/annmax_maps.png)

The map represent the time average over 1950-2090 of the annual maximum temperature.
