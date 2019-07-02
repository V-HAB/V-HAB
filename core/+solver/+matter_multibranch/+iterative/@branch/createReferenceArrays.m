function [ aiOriginalRowToNewRow, aiNewRowToOriginalRow, ...
           aiOriginalColToNewCol,aiNewColToOriginalCol] = ...
           createReferenceArrays(~, iOriginalRows, mbRemoveRow, mbRemoveColumn)
%CREATEREFERENCEARRAYS Summary of this function goes here
%   Detailed explanation goes here

aiRemoveRowIndexes = find(mbRemoveRow);
aiRemoveColIndexes = find(mbRemoveColumn);
            

aiOriginalRowToNewRow = (1:iOriginalRows)';
aiOriginalColToNewCol = 1:iOriginalRows;

aiNewRowToOriginalRow = (1:iOriginalRows)';
aiNewColToOriginalCol = 1:iOriginalRows;


for iBranch = 1:length(aiRemoveRowIndexes)
    
    aiOriginalRowToNewRow(aiRemoveRowIndexes(iBranch)+1:end) = aiOriginalRowToNewRow((aiRemoveRowIndexes(iBranch):end-1));
    aiOriginalRowToNewRow(aiRemoveRowIndexes(iBranch)) = 0;
    
    iNewRowIndex = find(aiNewRowToOriginalRow == aiRemoveRowIndexes(iBranch));
    
    aiNewRowToOriginalRow(iNewRowIndex:end) = aiRemoveRowIndexes(iBranch) + 1 : iOriginalRows + 1;
    aiNewRowToOriginalRow(end) = [];
    
    aiOriginalColToNewCol(aiRemoveColIndexes(iBranch)+1:end) = aiOriginalColToNewCol((aiRemoveColIndexes(iBranch):end-1));
    aiOriginalColToNewCol(aiRemoveColIndexes(iBranch)) = 0;
    
    iNewColIndex = find(aiNewColToOriginalCol == aiRemoveColIndexes(iBranch));
    
    aiNewColToOriginalCol(iNewColIndex:end) = aiRemoveColIndexes(iBranch) + 1 : iOriginalRows + 1;
    aiNewColToOriginalCol(end) = [];
    
end
end

