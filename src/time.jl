"""
    function temporalsubset(C::ClimGrid, startdate::Date, enddate::Date)

Returns the temporal subset of ClimGrid C. The temporal subset is defined by a start and end date.

"""
function temporalsubset(C::ClimGrid, datebeg::Tuple, dateend::Tuple)

    T = typeof(get_timevec(C)[1])
    timeV = get_timevec(C)
    idxtimebeg, idxtimeend = ClimateTools.timeindex(timeV, datebeg, dateend, T)

    startdate = ClimateTools.buildtimetype(datebeg, T)
    enddate = ClimateTools.buildtimetype(dateend, T)

    # some checkups
    @argcheck startdate <= enddate
    # @argcheck startdate >= C[1][Axis{:time}][1]
    # @argcheck enddate <= C[1][Axis{:time}][end]

    dataOut = C[1][Axis{:time}(idxtimebeg:idxtimeend)]

    # The following control ensure that a 1-timestep temporal subset returns a 3D Array with time information on the timestep. i.e. startdate == enddate
    if ndims(dataOut) == 2
        timeV = startdate
        latsymbol = Symbol(C.dimension_dict["lat"])
        lonsymbol = Symbol(C.dimension_dict["lon"])
        data2 = fill(NaN, (size(dataOut,1), size(dataOut, 2), 1))
        data2[:,:,1] = dataOut
        dataOut = AxisArray(data2, Axis{lonsymbol}(C[1][Axis{lonsymbol}][:]), Axis{latsymbol}(C[1][Axis{latsymbol}][:]), Axis{:time}(C[1][Axis{:time}][:]))

    end

    return ClimGrid(dataOut, longrid=C.longrid, latgrid=C.latgrid, msk=C.msk, grid_mapping=C.grid_mapping, dimension_dict=C.dimension_dict, timeattrib=C.timeattrib, model=C.model, frequency=C.frequency, experiment=C.experiment, run=C.run, project=C.project, institute=C.institute, filename=C.filename, dataunits=C.dataunits, latunits=C.latunits, lonunits=C.lonunits, variable=C.variable, typeofvar=C.typeofvar, typeofcal=C.typeofcal, varattribs=C.varattribs, globalattribs=C.globalattribs)

end

"""
    resample(C::ClimGrid, startmonth::Int64, endmonth::Int64)

Return a resampled subset of ClimGrid C based on months.
"""
function resample(C::ClimGrid, startmonth::Int64, endmonth::Int64)

    @argcheck startmonth >= minimum(Dates.month.(C[1][Axis{:time}][:]))
    @argcheck startmonth <= maximum(Dates.month.(C[1][Axis{:time}][:]))

    if startmonth <= endmonth
        # Each matrix [:,:,i] represent data for a day
        datain = C.data.data
        # Date vector
        datevecin = C[1][Axis{:time}][:]
        # Where are the data between startmonth and endmonth
        index = (Dates.month.(datevecin) .<= endmonth) .&  (Dates.month.(datevecin) .>= startmonth)
        # Keep only data between startmonth and endmonth
        dataout = datain[:,:,index]
        datevecout = datevecin[index]
        # Create the ClimGrid output
        lonsymbol = Symbol(C.dimension_dict["lon"])
        latsymbol = Symbol(C.dimension_dict["lat"])
        axisout = AxisArray(dataout, Axis{lonsymbol}(C[1][Axis{lonsymbol}][:]), Axis{latsymbol}(C[1][Axis{latsymbol}][:]),    Axis{:time}(datevecout))

    elseif endmonth < startmonth
        # Each matrix [:,:,i] represent data for a day
        datain = C.data.data
        # Date vector
        datevecin = C[1][Axis{:time}][:]
        # Where are the data between startmonth and endmonth
        index = (Dates.month.(datevecin) .<= endmonth) .|  (Dates.month.(datevecin) .>= startmonth)
        # Keep only data between startmonth and endmonth
        dataout = datain[:,:,index]
        datevecout = datevecin[index]
        # Create the ClimGrid output
        lonsymbol = Symbol(C.dimension_dict["lon"])
        latsymbol = Symbol(C.dimension_dict["lat"])
        axisout = AxisArray(dataout, Axis{lonsymbol}(C[1][Axis{lonsymbol}][:]), Axis{latsymbol}(C[1][Axis{latsymbol}][:]), Axis{:time}(datevecout))
    end

    return ClimGrid(axisout, longrid=C.longrid, latgrid=C.latgrid, msk=C.msk, grid_mapping=C.grid_mapping,dimension_dict=C.dimension_dict, timeattrib=C.timeattrib, model=C.model, frequency=C.frequency, experiment=C.experiment, run=C.run, project=C.project,institute=C.institute, filename=C.filename, dataunits=C.dataunits, latunits=C.latunits, lonunits=C.lonunits, variable=C.variable,typeofvar=C.typeofvar, typeofcal=C.typeofcal, varattribs=C.varattribs, globalattribs=C.globalattribs)
end

"""
    resample(C::ClimGrid, season::String)

Return a resampled subset of ClimGrid C for a given season. Season options are: "DJF" (December-February), "MAM" (March-May), "JJA" (June-August), "SON" (September-November)
"""
function resample(C::ClimGrid, season::String)
    if lowercase(season) == "djf"
      D = resample(C, 12, 2)
    elseif lowercase(season) == "mam"
      D = resample(C, 3, 5)
    elseif lowercase(season) == "jja"
      D = resample(C, 6, 8)
    elseif lowercase(season) == "son"
      D = resample(C, 9, 11)
    else
      error("Wrong season name. Options are DJF (December-February; Winter), MAM (March-May; Spring), JJA (June-August; Summer) and SON (September-November; Fall)")
    end

    return D
end

"""
    periodmean(C::ClimGrid; startdate::Tuple, enddate::Tuple)

Mean of array data over a given period.
"""
function periodmean(C::ClimGrid; start_date::Tuple=(Inf, ), end_date::Tuple=(Inf,), level=1)

    if start_date != (Inf,) || end_date != (Inf,)
        C = temporalsubset(C, start_date, end_date)
    end

    datain = C.data.data

    # Mean and squeeze
    if ndims(datain) == 2
        dataout = datain
    elseif ndims(datain) == 3
        if size(datain, 3) == 1 # already an average on single value
            dataout = dropdims(datain, dims=3)
        else
            dataout = dropdims(Images.meanfinite(datain, 3), dims=3)
        end
    elseif ndims(datain) == 4
        if size(datain, 4) == 1
            dataout = dropdims(datain[:, :, level, :], dims = 3)
        else
            dataout = dropdims(Images.meanfinite(datain, 3), dims=3)
        end
    end


    # Build output AxisArray
    FD = buildarray_climato(C, dataout)

    # Return climGrid type containing the indice
    return ClimGrid(FD, longrid=C.longrid, latgrid=C.latgrid, msk=C.msk, grid_mapping=C.grid_mapping, dimension_dict=C.dimension_dict, timeattrib=C.timeattrib, model=C.model, frequency=C.frequency, experiment=C.experiment, run=C.run, project=C.project, institute=C.institute, filename=C.filename, dataunits=C.dataunits, latunits=C.latunits, lonunits=C.lonunits, variable="periodmean", typeofvar=C.typeofvar, typeofcal="climatology", varattribs=C.varattribs, globalattribs=C.globalattribs)
end

"""
    timeindex(timeVec, start_date, end_date, T)

Return the index of time vector specified by start_date and end_date. T is the DateTime type (see NCDatasets.jl documentation).
"""
function timeindex(timeV, datebeg::Tuple, dateend::Tuple, T)

    # Start Date
    if !isinf(datebeg[1])
        # Build DateTime type
        start_date = ClimateTools.buildtimetype(datebeg, T)
        # @argcheck start_date >= timeV[1]
        idxtimebeg = findfirst(timeV .>= start_date)[1]
    else
        idxtimebeg = 1
    end
    # End date
    if !isinf(dateend[1])
        # Build DateTime type
        end_date = ClimateTools.buildtimetype(dateend, T)
        # @argcheck end_date <= timeV[end]
        idxtimeend = findlast(timeV .<= end_date)[1]
    else
        idxtimeend = length(timeV)
    end

    if !isinf(datebeg[1]) && !isinf(dateend[1])
        @argcheck start_date <= end_date
    end
    return idxtimebeg, idxtimeend
end

# function timeindex(C::ClimGrid, datebeg::Tuple, dateend::Tuple)
#
#     T = typeof(get_timevec(C)[1])
#
#     # Start Date
#     if !isinf(datebeg[1])
#
#         # Build DateTime type
#         start_date = ClimateTools.buildtimetype(datebeg, T)
#
#         # Check
#         @argcheck start_date >= timeV[1]
#
#         idxtimebeg = findfirst(timeV .>= start_date)[1]
#     else
#         idxtimebeg = 1
#     end
#
#     # End date
#     if !isinf(dateend[1])
#
#         # Build DateTime type
#         end_date = ClimateTools.buildtimetype(dateend, T)
#
#         @argcheck end_date <= timeV[end]
#
#         idxtimeend = findlast(timeV .<= end_date)[1]
#     else
#         idxtimeend = length(timeV)
#     end
#
#     if !isinf(datebeg[1]) && !isinf(dateend[1])
#         @argcheck start_date <= end_date
#     end
#
#     return idxtimebeg, idxtimeend
# end

"""
    buildtimetype(datetuple, f)

Returns the adequate DateTime for temporal subsetting using DateType *f*
"""
function buildtimetype(date_tuple, f)

    if length(date_tuple) == 1
        dateout = f(date_tuple[1], 01, 01)
    elseif length(date_tuple) == 2
        dateout = f(date_tuple[1], date_tuple[2], 01)
    elseif length(date_tuple) == 3
        dateout = f(date_tuple[1], date_tuple[2], date_tuple[3])
    elseif length(date_tuple) == 4
        dateout = f(date_tuple[1], date_tuple[2], date_tuple[3], date_tuple[4], 00, 00)
    elseif length(date_tuple) == 5
        dateout = f(date_tuple[1], date_tuple[2], date_tuple[3], date_tuple[4], date_tuple[5], 00)
    elseif length(date_tuple) == 6
        dateout = f(date_tuple[1], date_tuple[2], date_tuple[3], date_tuple[4], date_tuple[5], date_tuple[6])
    end

    return dateout
end

"""
    daymean(C::ClimGrid)

Returns the daily average given a sub-daily ClimGrid.
"""
function daymean(C::ClimGrid)

    datain = C[1].data
    timevec   = get_timevec(C)
    T = typeof(timevec[1])

    nbdays = unique(yearmonthday.(timevec))
    nbdays_len = length(nbdays)
    dataout = Array{typeof(datain[1])}(undef, (size(C[1], 1), size(C[1], 2), nbdays_len))
    newtime = Array{T}(undef, nbdays_len)

    # loop over year-month-days
    Threads.@threads for iday in 1:nbdays_len

        daytmp = nbdays[iday]
        datefind = T(daytmp[1], daytmp[2], daytmp[3])
        idx = findall(x -> Dates.year(x) == Dates.year(datefind) && Dates.month(x) == Dates.month(datefind) && Dates.day(x) == Dates.day(datefind), timevec)

        dataout[:, :, iday] = Statistics.mean(datain[:, :, idx], dims=3)
        newtime[iday] = datefind

    end

    # Build output AxisArray
    FD = buildarray_resample(C, dataout, newtime)

    return ClimGrid(FD, longrid=C.longrid, latgrid=C.latgrid, msk=C.msk, grid_mapping=C.grid_mapping, dimension_dict=C.dimension_dict, timeattrib=C.timeattrib, model=C.model, frequency="day", experiment=C.experiment, run=C.run, project=C.project, institute=C.institute, filename=C.filename, dataunits=C.dataunits, latunits=C.latunits, lonunits=C.lonunits, variable=C.variable, typeofvar=C.typeofvar, typeofcal=C.typeofcal, varattribs=C.varattribs, globalattribs=C.globalattribs)

end

"""
    daysum(C::ClimGrid)

Returns the daily sum given a sub-daily ClimGrid C.
"""
function daysum(C::ClimGrid)

    datain = C[1].data
    timevec   = get_timevec(C)
    T = typeof(timevec[1])

    nbdays = unique(yearmonthday.(timevec))
    nbdays_len = length(nbdays)
    dataout = Array{typeof(datain[1])}(undef, (size(C[1], 1), size(C[1], 2), nbdays_len))
    newtime = Array{T}(undef, nbdays_len)

    # loop over year-month-days
    Threads.@threads for iday in 1:nbdays_len

        daytmp = nbdays[iday]
        datefind = T(daytmp[1], daytmp[2], daytmp[3])
        idx = findall(x -> Dates.year(x) == Dates.year(datefind) && Dates.month(x) == Dates.month(datefind) && Dates.day(x) == Dates.day(datefind), timevec)

        dataout[:, :, iday] = Statistics.sum(datain[:, :, idx], dims=3)
        newtime[iday] = datefind

    end

    # Build output AxisArray
    FD = buildarray_resample(C, dataout, newtime)

    return ClimGrid(FD, longrid=C.longrid, latgrid=C.latgrid, msk=C.msk, grid_mapping=C.grid_mapping, dimension_dict=C.dimension_dict, timeattrib=C.timeattrib, model=C.model, frequency="day", experiment=C.experiment, run=C.run, project=C.project, institute=C.institute, filename=C.filename, dataunits=C.dataunits, latunits=C.latunits, lonunits=C.lonunits, variable=C.variable, typeofvar=C.typeofvar, typeofcal=C.typeofcal, varattribs=C.varattribs, globalattribs=C.globalattribs)

end

"""
    monthmean(C::ClimGrid)

Returns monthly means of ClimGrid C.
"""
function monthmean(C::ClimGrid)

    datain = C[1].data
    timevec = get_timevec(C)
    T = typeof(timevec[1])

    nbmonth = unique(yearmonth.(timevec))
    nbmonth_len = length(nbmonth)
    dataout = Array{typeof(datain[1])}(undef, (size(C[1], 1), size(C[1], 2), nbmonth_len))
    newtime = Array{T}(undef, nbmonth_len)

    # loop over year-month-days
    Threads.@threads for imonth in 1:nbmonth_len

        monthtmp = nbmonth[imonth]
        datefind = T(monthtmp[1], monthtmp[2])
        idx = findall(x -> Dates.year(x) == Dates.year(datefind) && Dates.month(x) == Dates.month(datefind), timevec)

        dataout[:, :, imonth] = Statistics.mean(datain[:, :, idx], dims=3)
        newtime[imonth] = datefind

    end

    # Build output AxisArray
    FD = buildarray_resample(C, dataout, newtime)

    return ClimGrid(FD, longrid=C.longrid, latgrid=C.latgrid, msk=C.msk, grid_mapping=C.grid_mapping, dimension_dict=C.dimension_dict, timeattrib=C.timeattrib, model=C.model, frequency="day", experiment=C.experiment, run=C.run, project=C.project, institute=C.institute, filename=C.filename, dataunits=C.dataunits, latunits=C.latunits, lonunits=C.lonunits, variable=C.variable, typeofvar=C.typeofvar, typeofcal=C.typeofcal, varattribs=C.varattribs, globalattribs=C.globalattribs)

end

"""
    monthsum(C::ClimGrid)

Returns monthly sums of ClimGrid C.
"""
function monthsum(C::ClimGrid)

    datain = C[1].data
    timevec = get_timevec(C)
    T = typeof(timevec[1])

    nbmonth = unique(yearmonth.(timevec))
    nbmonth_len = length(nbmonth)
    dataout = Array{typeof(datain[1])}(undef, (size(C[1], 1), size(C[1], 2), nbmonth_len))
    newtime = Array{T}(undef, nbmonth_len)

    # loop over year-month-days
    Threads.@threads for imonth in 1:nbmonth_len

        monthtmp = nbmonth[imonth]
        datefind = T(monthtmp[1], monthtmp[2])
        idx = findall(x -> Dates.year(x) == Dates.year(datefind) && Dates.month(x) == Dates.month(datefind), timevec)

        dataout[:, :, imonth] = Statistics.sum(datain[:, :, idx], dims=3)
        newtime[imonth] = datefind

    end

    # Build output AxisArray
    FD = buildarray_resample(C, dataout, newtime)

    return ClimGrid(FD, longrid=C.longrid, latgrid=C.latgrid, msk=C.msk, grid_mapping=C.grid_mapping, dimension_dict=C.dimension_dict, timeattrib=C.timeattrib, model=C.model, frequency="day", experiment=C.experiment, run=C.run, project=C.project, institute=C.institute, filename=C.filename, dataunits=C.dataunits, latunits=C.latunits, lonunits=C.lonunits, variable=C.variable, typeofvar=C.typeofvar, typeofcal=C.typeofcal, varattribs=C.varattribs, globalattribs=C.globalattribs)

end

"""
    timeresolution(timevec::Array{N,1} where N)

Return the time resolution of the vector timevec.

"""
function timeresolution(timevec::Array{N,1} where N)

    # timevec = (NetCDF.ncread(str, "time"))
    if length(timevec) > 1
        timediff = diff(timevec)[2]
        if timediff == 1. || timediff == 1
            return "24h"
        elseif round(timediff, digits=5) == round(12/24, digits=5)
            return "12h"
        elseif round(timediff, digits=5) == round(6/24, digits=5)
            return "6h"
        elseif round(timediff, digits=5) == round(3/24, digits=5)
            return "3h"
        elseif round(timediff, digits=5) == round(1/24, digits=5)
            return "1h"
        elseif round(timediff, digits=5) == 365.0 || round(timediff, digits=5) == 366.0 || round(timediff, digits=5) == 360.0
            return "Yearly"
        elseif timediff == 31.0 || timediff == 30.0 || timediff == 28.0 || timediff == 29.0
            return "Monthly"
        end
    else
        return "N/A"
    end
end

"""
    function pr_timefactor(rez::String)

Return the time factor that should be applied to precipitation to get accumulation for resolution "rez"

"""
function pr_timefactor(rez::String)

    if rez == "24h"
        return 86400.0
    elseif rez == "12h"
        return 43200.0
    elseif rez == "6h"
        return 21600.0
    elseif rez == "3h"
        return 10800.0
    elseif rez == "1h"
        return 3600.0
    elseif rez == "N/A"
        return 1.0
    end

end

"""
    function daymean_factor(rez::String)

Return the time factor that should be applied to precipitation to get accumulation for resolution "rez"

"""
function daymean_factor(rez::String)

    if rez == "24h" || rez == "day" || rez == "daily"
        return 1
    elseif rez == "12h"
        return 2
    elseif rez == "6h"
        return 4
    elseif rez == "3h"
        return 8
    elseif rez == "1h"
        return 24
    elseif rez == "N/A"
        return 1
    end

end

"""
    dropfeb29(C::ClimGrid)

Removes february 29th. Needed for bias correction.
"""
function dropfeb29(C::ClimGrid)
    date_vec = get_timevec(C) # [1][Axis{:time}][:]
    f = typeof(date_vec[1])
    feb29th = (Dates.month.(date_vec) .== Dates.month(f(2000, 2, 2))) .& (Dates.day.(date_vec) .== Dates.day(29))
    dataout = C[1].data[:, :, .!feb29th] # drop for data
    date_vec = date_vec[.!feb29th] # drop for calendar

    datevec_noleap = Array{DateTimeNoLeap}(undef, length(date_vec))

    for id = 1:size(date_vec, 1)
        datevec_noleap[id] = reinterpret(DateTimeNoLeap, date_vec[id])
    end

    dataout = buildarray_resample(C, dataout, datevec_noleap)

    return ClimGrid(dataout; longrid=C.longrid, latgrid=C.latgrid, msk=C.msk, grid_mapping=C.grid_mapping, dimension_dict=C.dimension_dict, timeattrib=C.timeattrib, model=C.model, frequency=C.frequency, experiment=C.experiment, run=C.run, project=C.project, institute=C.institute, filename=C.filename, dataunits=C.dataunits, latunits=C.latunits, lonunits=C.lonunits, variable=C.variable, typeofvar=C.typeofvar, typeofcal=C.typeofcal, varattribs=C.varattribs, globalattribs=C.globalattribs)
end

"""
    leapyears(datevec)

Returns the leap years contained into datevec.
"""
function leapyears(datevec)

    years = unique(Dates.year.(datevec))
    lyrs = years[Dates.isleapyear.(years)]

    return lyrs

end

function find_julianday_idx(julnb, ijulian, window)
    if ijulian <= window
        idx = @. (julnb >= 1) & (julnb <= (ijulian + window)) | (julnb >= (365 - (window - ijulian))) & (julnb <= 365)
    elseif ijulian > 365 - window
        idx = @. (julnb >= 1) & (julnb <= ((window-(365-ijulian)))) | (julnb >= (ijulian-window)) & (julnb <= 365)
    else
        idx = @. (julnb <= (ijulian + window)) & (julnb >= (ijulian - window))
    end
    return idx
end

"""
    yearmonthdayhour(dt::AbstractCFDateTime) -> (Int64, Int64, Int64, Int64)
Simultaneously return the year, month, day and hour parts of `dt`.
Author: Alexander-Barth (Github)
"""
yearmonthdayhour(dt::DT) where DT <: Dates.TimeType = (Dates.year(dt),Dates.month(dt), Dates.day(dt), Dates.hour(dt))
