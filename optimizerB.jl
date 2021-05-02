# import Pkg; 
# Pkg.add("GLPK")
# Pkg.add("JuMP")
# Pkg.add("CSV")
# Pkg.add("DataFrames")

const DATA_DIR = joinpath(@__DIR__, "data");

import DataFrames
import CSV
import Random
import GLPK
using JuMP

csv_df = CSV.read(joinpath(DATA_DIR, "courseData.csv"), DataFrames.DataFrame)

numStudents = 150 # TODO: Make more realistic?

Profs = Set(skipmissing(csv_df[!, 1])) # set of all profs

numProfs = length(Profs)

Courses = Set{String}() # set of all courses
profToCourseDict = Dict()

for i in 1:7
    currProf = csv_df[i, 1]
    currCourses = Set{String}()
    for j in 2:4
        if ~ ismissing(csv_df[i, j])
            push!(currCourses, csv_df[i, j])
            push!(Courses, csv_df[i, j] )
        end        
    end
    profToCourseDict[currProf] = currCourses
end


numCourses = length(Courses)

studentCourseRatings = rand(1:5, numStudents, numCourses)

function getRandomFixedSum(len, fixedSum)
    res = []
    currSum = 0
    
    for i in 1:len
        if currSum >= fixedSum
            break
        end
        
        if i == len
            push!(res, (fixedSum-currSum))
        else
            currRand = rand(0:(fixedSum-currSum))
            push!(res, currRand)
            currSum += currRand
        end
    end
    
    while length(res) < len
        push!(res, 0)
    end
    Random.shuffle!(res)
    replace!(res, 0 => -500)
    return res
end 



# creating course rating matrix

courseRatingMatrix = zeros(Int32, numStudents, numCourses)
courseRatingDict = Dict()

for i in 1:numStudents
    currRatings = getRandomFixedSum(numCourses,10)
    for (index, course) in enumerate(Courses)
        courseRatingDict[(i, course)] = currRatings[index]
    end
    courseRatingMatrix[i, :] = getRandomFixedSum(numCourses,10)
end

courseRatingMatrix
# courseRatingDict

courseTimingsDict = Dict{String, Any}()

for i in 1:numProfs
    currProf = csv_df[i, 1]
    days = csv_df[i, 5]
    startTime = csv_df[i, 6]
    EndTime = csv_df[i, 7]
    for course in profToCourseDict[currProf]
        courseTimingsDict[course] = [days, startTime, EndTime]
    end    
end

# courseTimingsDict

courseCapDict = Dict{String, Int8}()

for i in 1:numCourses
    courseCapDict[csv_df[i,9]] = csv_df[i,10]
end

# courseCapDict

courseTimeBool = Dict()

discreteTimes = []
TimeIdsSet = Set()
for k in 7:23
    for j in 0:5
        currTime = "$k$(j)0"
        currTime = parse(Int64, currTime)
        push!(discreteTimes, currTime)
    end
end

days = "MTWRF"
for currTime in discreteTimes
    for day in days
        currTimeString = string(currTime)
        currTimeId = "$(day)$(currTimeString)"
        push!(TimeIdsSet, currTimeId)
        for course in Courses
            if day in courseTimingsDict[course][1]
                startTime = courseTimingsDict[course][2]
                endTime = courseTimingsDict[course][3]
                # Not strictly greater than or less than because
                # courses can take place back to back.
                afterStartTime = currTime > startTime
                beforeEndTime = currTime < endTime
                
                if afterStartTime & beforeEndTime
                    courseTimeBool[(course, currTimeId)] = 1
                end
            end
        end
    end
end

for timeId in TimeIdsSet
    for course in Courses
        if ~ ((course, timeId) in keys(courseTimeBool))
            courseTimeBool[(course, timeId)] = 0
        end
    end
end

# courseTimeBool

model = Model(GLPK.Optimizer)

@variable(model, coursesBool[course in Courses], Bin)

@variable(model, studentAssignments[student in 1:numStudents, course in Courses], Bin)

@variable(model, z[student in 1:numStudents, course in Courses], Bin)

# linearizing quadratic terms here!
# got the trick from this website: https://orinanobworld.blogspot.com/2010/10/binary-variables-and-quadratic-terms.html
for student in 1:numStudents
    for course in Courses
        @constraint(model, z[student, course] <= studentAssignments[student, course])
        @constraint(model, z[student, course] >= 0) # not sure if needed
        @constraint(model, z[student, course] <= coursesBool[course])
        @constraint(model, z[student, course] >= (coursesBool[course] - (1-studentAssignments[student, course])))
    end
end

# Constraint: min and max number of electives given to a student
for student in 1:numStudents
    @constraint(model, sum(z[student, course] for course in Courses) <= 2)
end

# Constraint: Cap on # of students in a course
for course in Courses
    # TODO: hardcoding cap to be equal to 15 for now
    @constraint(model, sum(z[student, course] for student in 1:numStudents) <= 15) 
end


# Constraint: time conflict constraint
for timeId in TimeIdsSet
    for student in 1:numStudents
        @constraint(model, sum([courseTimeBool[(course, timeId)]*z[student, course] for course in Courses]) <= 1)
    end
end

# # Contraint: at most 6 courses to be chosen
# @constraint(model, sum([coursesBool[course] for course in Courses]) <= 6)

# Constraint: at most one course from one prof
for prof in Profs
    @constraint(model, 1 <= sum([coursesBool[course] for course in profToCourseDict[prof]]) <= 1)
end

# Objective
@objective(model, Max, sum([z[student, course]*courseRatingDict[student, course] for student in 1:numStudents, course in Courses]))

optimize!(model)

println(objective_value(model))

solution_summary(model)

# value.(coursesBool)

for course in coursesBool
    if getvalue(course) > 0
        println(course)
    end
end

# value.(studentAssignments)


