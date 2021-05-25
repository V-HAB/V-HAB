function fValue = Interpolation_Temperature_Data(afData, fTime)
%Use the linear interpolation method to get the temperaure value for the
%simulation.

% Unit conversion from second to day (s to d)
fTotalDays = fTime/(3600*24);

% completed days (integer)
iCompletedDays = floor(fTotalDays);

% current part of day
fPartOfDay = fTotalDays - iCompletedDays;

% Consider the edge value
    if fPartOfDay < afData(1,1)
        fValue = afData(1,2);
        return
    end

% Calculate the length of the experimental temperature array
iArrayLength = size(afData,1);

% Use the linear interpolation method to get the temperaure value for
% current time "fTime" in the simulation.
    for iSeq = 1:(iArrayLength - 1)
        if fPartOfDay >= afData(iSeq,1) && fPartOfDay < afData(iSeq+1,1)
            fValue = (fPartOfDay-afData(iSeq,1))*(afData(iSeq+1,2)-afData(iSeq,2))/(afData(iSeq+1,1)-afData(iSeq,1))...
                +afData(iSeq,2);
            return
        end
    end
end