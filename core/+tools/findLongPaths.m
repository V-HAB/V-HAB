function [csCompletedUUIDs, csActiveUUIDs, iMaxLevel] = findLongPaths(xInput, csCompletedUUIDs, csActiveUUIDs, bIsObject, iLevel, iMaxLevel, sPath)
%FINDLONGPATHS Finds long paths in the simulation object hierarchy
%   Starting with MATLAB 2020b a limit exists for the length of the object
%   hierarchy tree when they are saved to a MAT file. The limit seems to be
%   499 *unique* objects. Recursive pointers (i.e. parent->child and
%   child-> parent) seem to have no effect on this limit. When more than
%   499 objects are referenced in a row, an warning is thrown and the
%   object cannot be correctly saved. In some cases MATLAB crashes
%   completely during the save process. 
%   
%   This tool was created to help the user identify where in the model
%   these long paths exist. Once these instances are identified,
%   workarounds can be created. Please note that making the properties
%   transient does not work. This will allow saving, but upon load the same
%   limit is hit when reconstructing the object. The only known workaround
%   so far is to simply remove the referencing properties in order to break
%   the path.
%   
%   Once a simulation is complete, an object variable called 'oLastSimObj'
%   should be located in the base workspace. Call this function using the
%   following command:
%   
%   [csCompletedUUIDs, csActiveUUIDs, iMaxLevel] = tools.findLongPaths(oLastSimObj,{},{},true,0,0,'oLastSimObj');
%   
%   During the execution the tool will print a level, which is not actually
%   the hierarchy level, so don't worry if it is way above 500. It will
%   also print the current path to the object or property being inspected.
%   This path can be used to identify where the long paths originate and
%   how they propagate through the model. 

% Incrementing the level by one. 
iLevel = iLevel + 1;

% Printing the current level and path for the user 
fprintf('Level: %i\n', iLevel);
fprintf('%s\n', sPath);

% Check to see if we are higher than the previous maximum level. If so,
% save this level as the new max.
if iLevel > iMaxLevel
    iMaxLevel = iLevel;
end

% If we know that the current input is an object, we know we can query its
% properties in a certain way. If we know that it is not an object or its
% type is unknown, we have to do some more checking.
if bIsObject 
    % We compare if this object has already been completely checked or is
    % in the process of being checked. In the latter case we also need to
    % abort because we might otherwise be creating loops in this checker
    % that don't actually exist in the object hierarchy. 
    if any(strcmp(xInput.sUUID, csCompletedUUIDs)) || any(strcmp(xInput.sUUID, csActiveUUIDs))
        return;
    end
    
    % We haven't seen this object before, so we add it to the active UUIDs
    % list.
    csActiveUUIDs{end+1} = xInput.sUUID;
    
    % Getting the properties of the object and looping through them.
    csProperties = properties(xInput);
    for iProperty = 1:length(csProperties)
        % Updating the path
        sNewPath = [sPath, '.', csProperties{iProperty}]; 
        
        % Calling this function recursively. Note we are setting the
        % bIsObject input argument to false since we don't know the type of
        % this property. There are a few cases where the property cannot be
        % accessed without the simulation actually running. To catch these,
        % we enclose the recursive call in a try-catch-block and do some
        % error handling. 
        try
            [csCompletedUUIDs, csActiveUUIDs, iMaxLevel] = tools.findLongPaths(xInput.(csProperties{iProperty}), csCompletedUUIDs, csActiveUUIDs, false, iLevel, iMaxLevel, sNewPath);
        catch oErr
            if strcmp(oErr.identifier, 'phase:mixture:invalidAccessPartialPressures') ||...
                 strcmp(oErr.identifier, 'phase:mixture:invalidAccessHumidity') ||...
                 strcmp(oErr.identifier, 'phase:mixture:invalidAccessPartsPerMillion')
             continue;
            elseif strcmp(oErr.identifier, 'MATLAB:structRefFromNonStruct')
                % This catches dependent properties. We don't need those
                % for the purpose of this function anyway, we are only
                % interested in objects and dependent properties usually
                % return only numeric or logical values. 
                xProperty = findprop(xInput, csProperties{iProperty});
                if xProperty.Dependent
                    continue;
                else
                    keyboard();
                end
            else
                rethrow(oErr)
            end
        end
    end
    
    % We're done with this object so we can add its UUID to the completed
    % list and remove it from the active list. 
    csCompletedUUIDs{end+1} = xInput.sUUID;
    csActiveUUIDs(strcmp(csActiveUUIDs, xInput.sUUID)) = [];
    
    
else
    % We use a helper function to check the type of this input
    sReturn = checkType(xInput);
    
    % Based on the return string of the checkType() function we decide what
    % to do.
    switch sReturn
        case 'return'
            return;
        case 'struct'
            % This is a struct. First we need to check if this is a struct
            % array or a individual struct. 
            if length(xInput) > 1
                % This is a struct array, so we loop through all items,
                % update the path with the index of the current item in
                % paretheses (to look like the path we would type into the
                % command window) and then call this function recursively. 
                for iI = 1:length(xInput)
                    sNewPath = [sPath, sprintf('(%i)',iI)];
                    [csCompletedUUIDs, csActiveUUIDs, iMaxLevel] = tools.findLongPaths(xInput(iI), csCompletedUUIDs, csActiveUUIDs, false, iLevel, iMaxLevel, sNewPath);
                end
            else
                % xInput is an individual struct, so we get the fieldnames,
                % loop through each field, check the type and call this
                % function recursively. 
                csFieldNames = fieldnames(xInput);
                for iField = 1:length(csFieldNames)
                    sNestedReturn = checkType(xInput.(csFieldNames{iField}));
                    % Here we update the path with a dot character and the
                    % field name, again to make it look like the path in
                    % the command window.
                    sNewPath = [sPath, '.', csFieldNames{iField}];
                    switch sNestedReturn
                        case 'return'
                            continue;
                        case {'struct','cell'}
                            [csCompletedUUIDs, csActiveUUIDs, iMaxLevel] = tools.findLongPaths(xInput.(csFieldNames{iField}), csCompletedUUIDs, csActiveUUIDs, false, iLevel, iMaxLevel, sNewPath);
                        case 'base'
                            if length(xInput.(csFieldNames{iField})) > 1
                                for iJ = 1:length(xInput.(csFieldNames{iField}))
                                    % This is an object array, so we append the path with
                                    % the item number in parentheses.
                                    sBrandNewPath = [sNewPath, sprintf('(%i)',iJ)];
                                    
                                    [csCompletedUUIDs, csActiveUUIDs, iMaxLevel] = tools.findLongPaths(xInput.(csFieldNames{iField})(iJ), csCompletedUUIDs, csActiveUUIDs, true, iLevel, iMaxLevel, sBrandNewPath);
                                end
                            else
                                [csCompletedUUIDs, csActiveUUIDs, iMaxLevel] = tools.findLongPaths(xInput.(csFieldNames{iField}), csCompletedUUIDs, csActiveUUIDs, true, iLevel, iMaxLevel, sNewPath);
                            end
                        otherwise
                            [csCompletedUUIDs, csActiveUUIDs, iMaxLevel] = tools.findLongPaths(xInput.(csFieldNames{iField}), csCompletedUUIDs, csActiveUUIDs, true, iLevel, iMaxLevel, sNewPath);
                    end
                end
            end
        case 'cell'
            % The input is a cell, so we loop through all items. Since
            % cells can be heterogeneous, we need to check the type of each
            % item and then call this function recursively with the
            % according parameters.
            for iI = 1:length(xInput)
                sNestedReturn = checkType(xInput{iI});
                sNewPath = [sPath, sprintf('{%i}',iI)];
                switch sNestedReturn
                    case 'return'
                        continue;
                        
                    case {'struct','cell'}
                        [csCompletedUUIDs, csActiveUUIDs, iMaxLevel] = tools.findLongPaths(xInput{iI}, csCompletedUUIDs, csActiveUUIDs, false, iLevel, iMaxLevel, sNewPath);
                    case 'base'
                        if length(xInput{iI}) > 1
                            for iJ = 1:length(xInput{iI})
                                % This is an object array, so we append the path with
                                % the item number in parentheses.
                                sBrandNewPath = [sNewPath, sprintf('(%i)',iJ)];
                                
                                [csCompletedUUIDs, csActiveUUIDs, iMaxLevel] = tools.findLongPaths(xInput{iI}(iJ), csCompletedUUIDs, csActiveUUIDs, true, iLevel, iMaxLevel, sBrandNewPath);
                            end
                        else
                            [csCompletedUUIDs, csActiveUUIDs, iMaxLevel] = tools.findLongPaths(xInput{iI}, csCompletedUUIDs, csActiveUUIDs, true, iLevel, iMaxLevel, sNewPath);
                        end
                    otherwise
                        [csCompletedUUIDs, csActiveUUIDs] = tools.findLongPaths(xInput{iI}, csCompletedUUIDs, csActiveUUIDs, true, iLevel, iMaxLevel, sNewPath);
                end
            end
            
        case 'base'
            % The return type is a V-HAB object that inherits from the
            % 'base' class. We don't know if this is an individual object
            % or an object array, so we check that as well. 
            for iI = 1:length(xInput)
                if length(xInput) > 1
                    % This is an object array, so we append the path with
                    % the item number in parentheses. 
                    sNewPath = [sPath, sprintf('(%i)',iI)];
                else
                    sNewPath = sPath;
                end
                [csCompletedUUIDs, csActiveUUIDs, iMaxLevel] = tools.findLongPaths(xInput(iI), csCompletedUUIDs, csActiveUUIDs, true, iLevel, iMaxLevel, sNewPath);
            end
        otherwise
            % This is the catch all case. If there are user-defined classes
            % that don't inherit from base they will be caught here. If
            % necessary, the list of classes that are handled can be
            % adjusted in the checkType() function below. 
            try 
                sPath = [sPath, '.', class(xInput)];
                [csCompletedUUIDs, csActiveUUIDs, iMaxLevel] = tools.findLongPaths(xInput, csCompletedUUIDs, csActiveUUIDs, true, iLevel, iMaxLevel, sPath);
            catch
                error('Something went wrong');
            end
        
    end
    
end
end

function sReturn = checkType(xInput)
%CHECKTYPE Checks the type of the input

% First there are a bunch of types where we know that they will not be the
% sources or origins of long paths. For all of these we just return the
% string 'return'. For the others see below. 
if isa(xInput, 'char') || isa(xInput, 'string') || isa(xInput, 'numeric') || ...
   isa(xInput, 'logical') || isa(xInput, 'function_handle') || isa(xInput, 'meta.class') || ...
   isa(xInput, 'tools.debugOutput') || isa(xInput, 'scatteredInterpolant') || ...
   isa(xInput, 'containers.Map') || isempty(xInput) || isa(xInput, 'griddedInterpolant') || ...
   isa(xInput, 'solver.matter.base.type.callback') || isa(xInput, 'solver.matter.base.type.coefficient') || ...
   isa(xInput, 'solver.matter.base.type.hydraulic') || isa(xInput, 'solver.matter.base.type.manual')
    sReturn = 'return';
else
    if isa(xInput, 'struct')
        sReturn = 'struct';
    elseif isa(xInput, 'cell')
        sReturn = 'cell';
    elseif isa(xInput, 'base')
        sReturn = 'base';
    else
        sReturn = 'unknown';
    end
end

end