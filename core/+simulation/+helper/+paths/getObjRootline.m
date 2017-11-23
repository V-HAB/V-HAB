function [ coRootLine, sPath ] = getObjRootline(oObj)
%GETOBJROOTLINE Summary of this function goes here
%   Detailed explanation goes here
%
% Path from oLastSim obj / simulation.infrastructure


%TODO base version in simulation.helper.* (sys etc), vhab.sim.helper
%     version with stores, phases etc



    % Parent obj references:
    % <class name / isa()>, <attr with ref to parent without leading o>,
    % <attr name on parent pointing to children without leading to>
    cParentRefs = {
        'vsys',           'Parent',     'Children';
        'matter.store',   'Container',  'Stores';
        'matter.branch',  'Container',  'Branches';
        'matter.phase',   'Store',      'Phases';
        
        % Objects w/o root stuff
        'simulation.infrastructure', '', '';
        'event.timer', '', '';
        'matter.table', '', '';
        'simulation.configuration_parameters', '', '';
        'simulation.monitor', '', '';
        'tools.postprocessing.plotter.plotter_basic', '', '';
    };
    

    coRootLine = {};
    sPath = '';
    
    while ~isa(oObj, 'simulation.container')
        iMatch = [];
        
        for iRow = size(cParentRefs, 1):-1:1
            if isa(oObj, cParentRefs{iRow, 1})
                iMatch = iRow;
                
                break;
            end
        end
        
        if isempty(iMatch)
            
            warning('simulation.helper.paths.getObjRootline - obj type seems to be unknown: %s', oObj.sEntity);
            oObj = [];
            
            break;
            
        elseif isempty(cParentRefs{iRow, 2})
            oObj = [];
            break;
        end
        
        
        % Now iRow points to the last elem in cParentRefs whose first
        % column value isa() oObj
        oParent = oObj.([ 'o' cParentRefs{iRow, 2} ]);
        
        % Just return rootline until this point
        if isempty(oParent)
            oObj = [];
            break;
        end
        
        
        coRootLine{end + 1} = oParent;
        
        toParentChildStruct = oParent.([ 'to' cParentRefs{iRow, 3} ]);
        csParentChildKeys   = fieldnames(toParentChildStruct);
        
        for iC = 1:length(csParentChildKeys)
            sC = csParentChildKeys{iC};
            
            if oObj == toParentChildStruct.(sC)
                sPath = [ '.to' cParentRefs{iRow, 3} '.' sC sPath ];
                
                break;
            end
        end
        
        oObj = oParent;
    end
    
    
    
    % Revert rootline
    coRootLine = coRootLine(end:-1:1);
    
    % Sim container name
    % Just if while loop above did find the sim.container (else oObj set to
    % empty)
    if ~isempty(oObj)
        sPath = [ oObj.sName sPath ];
        %sPath = [ 'oSimulationContainer' sPath ];
    end
    


end

