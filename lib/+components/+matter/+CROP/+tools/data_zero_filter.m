function afTestData = data_zero_filter(mTestData)
%This function is used to filter the unmeasured data in the data series.

% Calculate the size of data matrix
ilen = size(mTestData,1);
iDataSet = size(mTestData,2);

% Generate a empty array for the simulation result array
afTestData = zeros(ilen,1);

% Filter the unmeasured data
for i = 1:ilen
   sum_sg = sum(mTestData(i,:));
   icount = iDataSet;
   for j = 1:iDataSet
       if mTestData(i,j) == 0
           icount = icount - 1;
       end
   end
   if icount ~= 0
   afTestData(i) = sum_sg/icount;
   else
       afTestData(i) = 0;
   end
end