function fValue = Interpolation_ExpData(iDay,afTime_Series,afSimulation_Results,aTestData,iTestTurn)
%Use the linear interpolation method to get the simulation result array
%from a larger data array.

% Filter the useless data
if iTestTurn >0 && iDay == 0
    fValue = 0;
    return
end
if iDay < afTime_Series(1)
    fValue = afSimulation_Results(1);
    return
end

% Calculate the length of larger data array
ilen = length(afTime_Series);

% Use the linear interpolation method to get the simulation result array
for i = 1:(ilen-1)
    if iDay >= afTime_Series(i) && iDay < afTime_Series(i+1)
        fValue = (iDay-afTime_Series(i))*(afSimulation_Results(i+1)-afSimulation_Results(i))/(afTime_Series(i+1)-afTime_Series(i))...
            +afSimulation_Results(i);
        return
    elseif (iDay >= afTime_Series(i) && afTime_Series(i+1)==0) || ...
            (iDay >= afTime_Series(i) && i==ilen)
        fValue = afSimulation_Results(i);
        return
    end
end
        fValue = aTestData(iTestTurn);
        return
end