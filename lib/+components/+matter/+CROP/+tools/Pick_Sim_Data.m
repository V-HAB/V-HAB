function afSimData = Pick_Sim_Data(aiTestDays, afTime_Series,afSimulation_Results,afTestData)
%This function is used to get the simulation result array for the residual
%function from a larger data array.

% Calculate the number of days in the experimental data
ilen = length(aiTestDays);

% Generate a empty array for the simulation result array
afSimData = zeros(ilen,1);

% Use the linear interpolation method to get the simulation result array 
% from a larger data array.
for iSeq = 1:ilen
    afSimData(iSeq) = suyi.CROP.tools.Interpolation_ExpData(aiTestDays(iSeq),afTime_Series,afSimulation_Results,afTestData,iSeq);
end

end