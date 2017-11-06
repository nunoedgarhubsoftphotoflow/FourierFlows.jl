__precompile__()

using JLD2, HDF5

import Base: getindex, setindex!, push!, append!, fieldnames

export Output, saveoutput, saveproblem, groupsize




gridfieldstosave = [:nx, :ny, :Lx, :Ly, :X, :Y]


""" Output type for FourierFlows problems. """
type Output
  fields::Dict{Symbol, Function}
  prob::Problem
  filename::String
end

""" Constructor for Outputs with no fields. """
function Output(prob::Problem, filename::String)
  fields = Dict{Symbol, Function}()
  saveproblem(prob, filename)
  Output(fields, prob, filename)
end

""" Constructor for Outputs in which the name, field pairs are passed as
tupled arguments."""
function Output(prob::Problem, filename::String, fieldtuples...)
  Output(Dict{Symbol, Function}(
      [(symfld[1], symfld[2]) for symfld in fieldtuples]
    ), prob, filename)
end
  
""" Get the current output field. """
function getindex(out::Output, key)
  out.fields[key](out.prob)  
end

function setindex!(out::Output, calcfield::Function, fieldname::Symbol)
  out.fields[fieldname] = calcfield  
end

""" Add output name, calculator pairs when supplied as tupled arguments. """
function push!(out::Output, newfields...)
  for i = length(newfields)
    out.fields[newfields[i][1]] = newfields[i][2]
  end
end

""" Append a dictionary of name, calculator pairs to the dictionary of
output fields. """
function append!(out::Output, newfields::Dict{Symbol, Function})
  for key in keys(newfields)
    push!(out, (key, newfields[key]))
  end
end

function fieldnames(out::Output)
  fieldnames(out.fields)
end

""" Save the current output fields. """
function saveoutput(out::Output)
  step = out.prob.step
  groupname = "timeseries"

  jldopen(out.filename, "a+") do file
    file[$groupname/t/$step] = out.prob.t
    for fieldname in keys(out.fields)
      file["$groupname/$fieldname/$step"] = out[fieldname]
    end
  end

  nothing
end

""" Save attributes of the Problem associated with the given Output. """
function saveproblem(out::Output)
  saveproblem(out.prob, out.filename)
end





""" Original output type for FourierFlows problems. """
type OldOutput
  name::String
  calc::Function
  prob::Problem
  filename::String
end

function Output(name::String, calc::Function, prob::Problem, filename::String)
  OldOutput(name, calc, prob, filename)
end

""" Save output to file. """
function saveoutput(out::OldOutput)
  step = out.prob.step
  groupname = "timeseries"
  name = out.name

  jldopen(out.filename, "a+") do file
    file["$groupname/$name/$step"] = out.calc(out.prob)
    file["$groupname/t/$step"]     = out.prob.t
  end

  nothing
end


""" Save an array of outputs to file. """
function saveoutput(outs::AbstractArray)

  step = outs[1].prob.step
  groupname = "timeseries"

  jldopen(outs[1].filename, "a+") do file
    file["$groupname/t/$step"] = outs[1].prob.t # save timestamp
    for out in outs # save output data 
      name = out.name
      file["$groupname/$name/$step"] = out.calc(out.prob)
    end
  end

  nothing
end


""" Find the number of elements in a JLD2 group. """
function groupsize(group::JLD2.Group)
  try
    value = length(group.unwritten_links) + length(group.written_links)
  catch
    value = length(group.unwritten_links)
  end
  return value
end



""" Save certain aspects of a Problem. Entire problems cannot be saved
in general, because functions cannot be saved (and functions may use
arbitrary numbers of global variables that cannot be included in a saved 
object). """
function saveproblem(prob::AbstractProblem, filename::String)

  jldopen(filename, "a+") do file
      file["timestepper/dt"] = prob.ts.dt
      for field in gridfieldstosave
        file["grid/$field"] = getfield(prob.grid, field)
      end

      for name in filenames(prob.params)
        field = getfield(prob.params, name)
        if !(typeof(field) <: Function)
          file["params/$name"] = field
        end
      end
  end

  nothing
end
