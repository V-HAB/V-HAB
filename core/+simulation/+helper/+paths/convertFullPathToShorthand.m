function sShortPath = convertFullPathToShorthand(sPath)
%CONVERTFULLPATHTOSHORTHAND Converts full V-HAB object paths into shorthand
%   In an effort to shorten the paths used for logging, field names and
%   other uses, this function replaces several strings, like for instance
%   '.toStores.', with shorter versions. In this example it would be ':s:'.


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

