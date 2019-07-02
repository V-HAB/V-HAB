function [tVHAB_Objects, tSystems] = createHierarchy(tVHAB_Objects, tSystemIDtoLabel)
%% Create hierarchy
% now we have the necessary data from the xml, but it is not ordered
% according to the specified hierarchy. Before we create the V-HAB system
% we have to order it into the correct hierarchy so that we know the
% correct paths for the logging and plotting

% Variable to check which systems are already ordered into the correct
% hierarchy level
mbOrderedSystems = false(1, length(tVHAB_Objects.System));

% First we loop through the systems and find the overall parent system
% (which has the ID 1)
for iSystem = 1:length(tVHAB_Objects.System)
    if strcmp(tVHAB_Objects.System{iSystem}.ParentID, 'p_1')
        iRootSystem = iSystem;
        sRootSystemID = tVHAB_Objects.System{iSystem}.id;
        tSystems.(tSystemIDtoLabel.(sRootSystemID)) = tVHAB_Objects.System{iRootSystem};
        tVHAB_Objects.System{iRootSystem}.sFullPath = tVHAB_Objects.System{iRootSystem}.label;
        mbOrderedSystems(iRootSystem) = true;
        break
    end
end

% Now we loop through the systems until we have ordered all existing
% systems into the hierarchy
tSystems.(tSystemIDtoLabel.((sRootSystemID))).Children = struct();

while any(~mbOrderedSystems)
    
    for iSystem = 1:length(tVHAB_Objects.System)
        if ~mbOrderedSystems(iSystem)
            
            sID = tVHAB_Objects.System{iSystem}.id;
            sSupraSystemID = tVHAB_Objects.System{iSystem}.ParentID;
            sSupraSystemField = tSystemIDtoLabel.(sSupraSystemID);

            bAbort = false;
            while (~strcmp(sSupraSystemID, sRootSystemID))
                if bAbort
                    % the parent system (or one of its supra systems) was
                    % not yet ordered. Therefore break the while loop and
                    % redo this once it is reordered
                    break
                end
                
                for iSupraSystem = 1:length(tVHAB_Objects.System)
                    if strcmp(tVHAB_Objects.System{iSupraSystem}.id, sSupraSystemID)
                        if ~mbOrderedSystems(iSupraSystem)
                            bAbort = true;
                            break
                        else
                            sSupraSystemField = [tSystemIDtoLabel.(tVHAB_Objects.System{iSupraSystem}.ParentID) , '.toChildren.', sSupraSystemField];
                            sSupraSystemID = tVHAB_Objects.System{iSupraSystem}.ParentID;
                            break
                        end
                    end
                end
            end
            
            % If parent system (or one of its suprasystems) was not yet
            % ordered, we skip to the next system
            if ~bAbort
                sSupraSystemField = [sSupraSystemField, '.toChildren.', tSystemIDtoLabel.(sID)];
                fields = textscan(sSupraSystemField,'%s','Delimiter','.');
                tSystems = setfield(tSystems, fields{1}{:},  tVHAB_Objects.System{iSystem});
                tVHAB_Objects.System{iSystem}.sFullPath = sSupraSystemField;
                mbOrderedSystems(iSystem) = true;
            else
                continue
            end
        end
    end
end
end