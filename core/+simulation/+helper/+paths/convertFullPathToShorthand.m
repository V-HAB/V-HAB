function sShortPath = convertFullPathToShorthand(sPath)
%CONVERTFULLPATHTOSHORTHAND Summary of this function goes here
%   Detailed explanation goes here


    % .toChildren. to /
    sShortPath  = strrep(sPath, '.toChildren.', '/');
    
    
    tsConv = struct(...
        'c', 'Children', ...
        'b', 'Branches', ...
        's', 'Stores', ...
        'p', 'Phases' ...
    );
    csConv = fieldnames(tsConv);

    for iI = 1:length(csConv)
        sShortPath  = strrep(sShortPath, [ '.to' tsConv.(csConv{iI}) '.' ], [ ':' csConv{iI} ':' ]);
    end

end

