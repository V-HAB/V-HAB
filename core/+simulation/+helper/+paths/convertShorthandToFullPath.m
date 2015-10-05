function sPath = convertShorthandToFullPath(sShortPath)
%CONVERTSHORTHANDTOFULLPATH Summary of this function goes here
%   Detailed explanation goes here


    sPath  = strrep(sShortPath, '/', ':c:');
    tsConv = struct(...
        'c', 'Children', ...
        'b', 'Branches', ...
        's', 'Stores', ...
        'p', 'Phases' ...
    );
    csConv = fieldnames(tsConv);

    for iI = 1:length(csConv)
        sPath  = strrep(sPath, [ ':' csConv{iI} ':' ], [ '.to' tsConv.(csConv{iI}) '.' ]);
    end

end

