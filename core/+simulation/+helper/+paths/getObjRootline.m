function [ coRootLine, sPath ] = getObjRootline(oInputObject)
%GETOBJROOTLINE Returns the parent objects of the provided object
%   This function takes the provided object and via a (limited) set of
%   pre-defined paths traverses back up the object hierarchy until there is
%   no clear parent object. It then returns references to all of the
%   objects that are above the input object in a linear cell with the first
%   object being the most basic object in the tree.
%   Additionally, the function returns the path of the input object as a
%   string.

% Creating a cell with parent object references:
% First column:     class name that can be used with the isa() method
% Second column:    class attribute that references the object's parent 
%                   without the leading 'o'
% Third column:     name of the attribute on the parent object pointing to 
%                   its children without the leading 'to'
cParentRefs = {
    % Objects with parents
    'vsys',               'Parent',    'Children';
    'matter.store',       'Container', 'Stores';
    'matter.branch',      'Container', 'Branches';
    'matter.phase',       'Store',     'Phases';
    'thermal.capacity',   'Phase',     'Capacity';
    'thermal.branch',     'Container', 'ThermalBranches';
    'electrical.branch',  'Circuit',   'Branches';
    'electrical.store',   'Circuit',   'Stores';
    'electrical.node',    'Circuit',   'Nodes';
    'electrical.circuit', 'Parent',    'Circuits';
    
    % Objects w/o root stuff
    'simulation.infrastructure', '', '';
    'event.timer', '', '';
    'matter.table', '', '';
    'simulation.configurationParameters', '', '';
    'simulation.monitor', '', '';
    'tools.postprocessing.plotter.plotter_basic', '', '';
    };


% Initializing the return variables. Since we don't yet now how deep the
% hierarchy is, we initialize the cell with 100 items, that should be more
% than enough for the models we are building in V-HAB. 
coRootLine = cell(100,1);
sPath = '';

% Next we enter a while loop in which we continue iterating as long as the
% loop variable 'oObject' is not the simulation container, which is the
% highest level object. 

% Initializing the loop variable
oObject = oInputObject;

% We need to count how many objects we gave added to the return variable,
% so we initialize a counter here.
iNumberOfObjects = 1;

while ~isa(oObject, 'simulation.container')
    % First we check if the class can be found in the first column of the
    % cParentRefs cell. 
    abMatch = cellfun(@(cCell) isa(oObject, cCell), cParentRefs(:,1));
    
    % If there are no matches, then the object's class hasn't been defined
    % in the cParentRefs cell. So we let the user know and abort the loop.
    if ~any(abMatch)
        warning('simulation.helper.paths.getObjRootline - obj type seems to be unknown: %s', oObject.sEntity);
        oObject = [];
        break;
        
    elseif isempty(cParentRefs{abMatch, 2})
        % In this case, the object does not have a parent, so we abort the
        % loop.
        oObject = [];
        break;
    end
    
    % Now we can get the parent object of the current object.
    oParent = oObject.([ 'o' cParentRefs{abMatch, 2} ]);
    
    % If the parent property of this object is empty, we abort.
    if isempty(oParent)
        oObject = [];
        break;
    end
    
    % Adding the parent object to the return variable and incrementing the
    % counter. 
    coRootLine{iNumberOfObjects} = oParent;
    iNumberOfObjects = iNumberOfObjects + 1;
    
    % Now we need to find the reference to the current object in its
    % parent. First we get the struct containing the appropriate child
    % objects from the parent (e.g. toStores).
    toParentChildStruct = oParent.([ 'to' cParentRefs{abMatch, 3} ]);
    
    % Getting the field names from the struct
    csParentChildKeys   = fieldnames(toParentChildStruct);
    
    % Now we loop through all the children 
    for iChild = 1:length(csParentChildKeys)
        % Getting the name of the next child object in the struct
        sChildName = csParentChildKeys{iChild};
        
        % Comparing the current object the the one we are looking at in the
        % parent object
        if oObject == toParentChildStruct.(sChildName)
            % The objects match, so we add the child's name to the path and
            % break the for loop, so we don't do unnecessary iterations.
            sPath = strcat('.to', cParentRefs{abMatch, 3}, '.', sChildName, sPath);
            
            break;
        end
    end
    
    % For the next iteration we want to go up one level of hierarchy, so we
    % set the loop variable oObject to its parent. 
    oObject = oParent;
end

% Since we pre-allocated the coRootLine variable with 100 fields, we now
% have to delete the ones we did not fill.
coRootLine = coRootLine(~cellfun('isempty',coRootLine));

% We want the resulting cell to have the most basic object in the first
% field, since we went the other direction starting with the input object,
% we have to flip the coRootLine cell. 
coRootLine = flip(coRootLine);

% If we went all the way up to the simulation container or any of the other
% objects without a parent, the oObject variable will not be empty. So the
% last thing we need to do is to add this object's name to the beginning of
% the path return variable. 
if ~isempty(oObject)
    sPath = [ oObject.sName sPath ];
end

end

