const DATA_DIR = joinpath(@__DIR__, "data");

import DataFrames
import CSV
import Random
import GPLK
using JuMP

csv_df = CSV.read(joinpath(DATA_DIR, "courseData.csv"), DataFrames.DataFrame)

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
numStudents = 50

studentCourseRatings = rand(1:5, numStudents, numCourses)

function getRandomFixedSum(len, fixedSum)
    res = []
    currSum = 0
    
    for i in 1:len
        if currSum >= fixedSum
            break
        end
        
        currRand = rand(0:(fixedSum-currSum))
        push!(res, currRand)
        currSum += currRand
    end
    
    while length(res) < len
        push!(res, 0)
    end
    Random.shuffle!(res)
    return res
end 


# creating course rating matrix

courseRatingMatrix = zeros(Int8, numStudents, numCourses)

for i in 1:numStudents
    courseRatingMatrix[i, :] = getRandomFixedSum(numCourses,10)
end

# courseRatingMatrix

csv_df[:, :]

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

courseTimingsDict

courseCapDict = Dict{String, Int8}()

for i in 1:numCourses
    courseCapDict[csv_df[i,9]] = csv_df[i,10]
end

courseCapDict


# TIME CONFLICT PREPROCESSING
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

courseTimeBool


model = Model(GLPK.Optimizer)

for timeId in TimeIdsSet
    @constraint(model, )
