function findLoops()
global iLength
global cfAllLoops
global iLoops
mfConnections = [1 1 0 1 0 0; 1 1 1 1 0 1; 0 1 1 0 1 1; 1 1 0 1 1 0; 0 0 1 1 1 1; 0 1 1 0 1 1];
iLength = length(mfConnections);
mbConnections = logical(mfConnections);
mbConnections(logical(eye(iLength))) = false;
cfAllLoops = cell(iLength * 10, 1);
iLoops = 0;

for iI = 1:iLength
    for iJ = 1:iLength
        if mbConnections(iI,iJ)
            getPath(iI, iJ, mbConnections);
        end
    end

end

cfAllLoops(cellfun(@isempty,cfAllLoops)) = [];


cfShortenedLoops = cellfun(@(afLoop) afLoop(1:end-1), cfAllLoops, 'UniformOutput', false);

cfSortedShortenedLoops = cellfun(@sort, cfShortenedLoops, 'UniformOutput', false);

afSortedShortenedLoops = zeros(length(cfSortedShortenedLoops),1);
for iI = 1:length(cfSortedShortenedLoops)
    fLoopCode = 0;
    for iJ = 1:length(cfSortedShortenedLoops{iI})
        fLoopCode = fLoopCode + cfSortedShortenedLoops{iI}(end +1 -iJ) * 10^(iJ-1);
    end
    
    afSortedShortenedLoops(iI) = fLoopCode;
end

[afUniqueLoopCodes, aiUniqueLoopIndexes, ~ ] = unique(afSortedShortenedLoops);

% Recreate the mbConnections matrix from the unique loops to verify, that
% all branches are contained in the found loops. We will add the loops one
% by one to the resulting array. If the validation matrix does not change
% if a loop is added, that means that it is not one of the smallest
% possible loops. 


mbLogMatrix = false(iLength);
abLoops = false(length(aiUniqueLoopIndexes),1);

for iI = 1:length(afUniqueLoopCodes)
    abTestLoops = abLoops;
    abTestLoops(iI) = true;
    mbValidationMatrix = createMatrix(aiUniqueLoopIndexes(abTestLoops));
    
    if ~isequal(mbLogMatrix, mbValidationMatrix)
        mbLogMatrix = mbValidationMatrix;
        abLoops(iI) = true;
        if isequal(mbValidationMatrix, mbConnections)
            break;
        end
    end
    
    
end

cfLoops = cfAllLoops(aiUniqueLoopIndexes(abLoops));

end

function getPath(iStart, iNode, mbConnections, afPath)
    global iLength cfAllLoops iLoops
    
    if nargin > 3
        % Not first call
        if length(afPath) > iLength + 1
            return;
        end
        
        if mbConnections(iNode, iStart)
            iLoops = iLoops + 1;
            cfAllLoops{iLoops} = [ afPath iNode iStart ];
        end
        
        for iI = 1:iLength
            % Have we been here before?
            if any(afPath == iI)
                continue;
            end
            
            if mbConnections(iNode, iI)
                if mbConnections(iI,iStart)
                    iLoops = iLoops + 1;
                    cfAllLoops{iLoops} = [ afPath iNode iI iStart ];
                    continue;
                else
                    for iJ = 1:iLength
                        if mbConnections(iI,iJ)
                            % Have we been here before?
                            if any(afPath == iJ)
                                continue;
                            end
                            if iJ == iStart
                                continue;
                            elseif iJ ~= afPath(end) && ~any(afPath == iJ) && iJ ~= iNode
                                getPath(iStart, iI, mbConnections, [ afPath iNode ]);
                            end
                        end
                    end
                end
            end
        end
        
    else
        % First call
        for iI = 1:iLength
            if mbConnections(iNode, iI) && iI ~= iStart
                if mbConnections(iI,iStart)
                    iLoops = iLoops + 1;
                    cfAllLoops{iLoops} = [iStart iNode iI iStart];
                else
                    for iJ = 1:iLength
                        if mbConnections(iI,iJ)
                            if iJ == iStart
                                continue;
                            elseif iJ ~= iNode
                                afPath = [ iStart iNode iI ];
                                getPath(iStart, iJ, mbConnections, afPath);
                            end
                        end
                    end
                end
            end
        end
    end
end

function mbMatrix = createMatrix(aiIndexes)
    global cfAllLoops iLength
    
    miMatrix = zeros(iLength);
    
    for iI = 1:length(aiIndexes)
        for iJ = 1:(length(cfAllLoops{aiIndexes(iI)})-1)
            miMatrix(cfAllLoops{aiIndexes(iI)}(iJ),cfAllLoops{aiIndexes(iI)}(iJ+1)) = 1;
        end
    end
    
    % The initial matrix is symmetric, so we need to make sure, that all
    % connections are made in both directions.
    for iI = 1:iLength
        for iJ = 1:iLength
            if miMatrix(iI,iJ)
                miMatrix(iJ,iI) = 1;
            end
        end
    end
    
    
    % We need to make the matrix a logical one, because that's what we'll
    % be comparing it to.
    mbMatrix = logical(miMatrix);
    
end



