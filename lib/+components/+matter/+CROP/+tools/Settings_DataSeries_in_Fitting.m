function [iSequence, aNr_DataSet] = Settings_DataSeries_in_Fitting(sSeries)
%Get the corresponding sequence of the data series in the parameter set

if sSeries == 'C' % 3.5% series
    aNr_DataSet = [2 3 4 5];
    iSequence = 0;
elseif sSeries == 'H' % 7% series
    aNr_DataSet = [2 3];
    iSequence = 1;
elseif sSeries == 'I' % 20% series
    aNr_DataSet = [2 3];
    iSequence = 2;
elseif sSeries == 'D' % 40% series
    aNr_DataSet = [2 3 4];
    iSequence = 3;
elseif sSeries == 'E' % 60% series
    aNr_DataSet = [2 4];
    iSequence = 4;
elseif sSeries == 'F' % 80% series
    aNr_DataSet = [2 3 4];
    iSequence = 5;
end
end