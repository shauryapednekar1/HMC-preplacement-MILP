const DATA_DIR = joinpath(@__DIR__, "data");

import DataFrames

import XLSX

passport_data = CSV.read(
    joinpath(DATA_DIR, "passport-index-matrix.csv"),
    DataFrames.DataFrame;
    copycols = true,
)

for i in 1:DataFrames.nrow(passport_data)
    for j in 2:DataFrames.ncol(passport_data)
        if passport_data[i, j] == -1 || passport_data[i, j] == 3
            passport_data[i, j] = 1
        else
            passport_data[i, j] = 0
        end
    end
end

using JuMP
import GLPK

# First, create the set of countries:

World = names(passport_data)[2:end]

# Then, create the model and initialize the decision variables:
model = Model(GLPK.Optimizer)
@variable(model, pass[cntr in World], Bin)

# Define the objective function

@objective(model, Min, sum(pass[cntr] for cntr in World))

#-

@constraint(model, [dest in World], passport_data[:, dest]' * pass >= 1)

# Now optimize!

optimize!(model)
println("Minimum number of passports needed: ", objective_value(model))

#-

optimal_passports = [cntr for cntr in World if value(pass[cntr]) > 0.5]
println("Countries:")
for p in optimal_passports
    println(" ", p)
end

# !!! note
#     We use `value(pass[i]) > 0.5` rather than `value(pass[i]) == 1` to avoid
#     excluding solutions like `pass[i] = 0.99999` that are "1" to some
#     tolerance.