function fValue = Interpolation_Temperature_Data(afData, fTime)
%Use the linear interpolation method to get the temperaure value for the
%simulation.

% Unit conversion from second to day (s to d)
fTime_d = fTime/(3600*24);

% Consider the edge value
if fTime_d < afData(1,1)
    fValue = afData(1,2);
    return
end

% Calculate the length of the experimental temperature array
ilen = size(afData,1);

% Use the linear interpolation method to get the temperaure value for
% current time "fTime" in the simulation.
for iSeq = 1:ilen
    if fTime_d >= afData(iSeq,1) && fTime_d < afData(iSeq+1,1)
        fValue = (fTime_d-afData(iSeq,1))*(afData(iSeq+1,2)-afData(iSeq,2))/(afData(iSeq+1,1)-afData(iSeq,1))...
            +afData(iSeq,2);
        return
    elseif (fTime_d >= afData(iSeq,1) && afData(iSeq+1,1)==0) || ...
            (fTime_d >= afData(iSeq,1) && iSeq==ilen)
        fValue = afData(iSeq,2);
        return
    end
end
end