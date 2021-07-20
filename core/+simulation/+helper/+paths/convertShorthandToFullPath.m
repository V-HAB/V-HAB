function sPath = convertShorthandToFullPath(sShortPath)
%CONVERTSHORTHANDTOFULLPATH Converts shorthand object paths into full V-HAB paths
%   In an effort to shorten the paths used for logging, field names and
%   other uses, several strings, like for instance '.toStores.', are
%   replaced with shorter versions. In this example it would be ':s:'. This
%   function reverses these replacements and returns the full V-HAB object
%   path for programmatic use.

    sPath  = strrep(sShortPath, '/', ':c:');
    tsConv = struct(...
        'c', 'Children', ...
        'b', 'Branches', ...
        't', 'ThermalBranches', ...
        's', 'Stores', ...
        'p', 'Phases' ...
    );
    csConv = fieldnames(tsConv);

    for iI = 1:length(csConv)
        sPath  = strrep(sPath, [ ':' csConv{iI} ':' ], [ '.to' tsConv.(csConv{iI}) '.' ]);
    end

end

