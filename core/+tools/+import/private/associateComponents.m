function tVHAB_Objects = associateComponents(tVHAB_Objects, csPhases, csF2F, csSystems)
%% Associate store, phases, branches etc to the corresponding systems
% As the next step we now add the defined V-HAB objects from draw io to
% their corresponding systems in the created tVHAB_Objects.System variable
% to make it easier later on to define the code for the systems
for iSystem = 1:length(tVHAB_Objects.System)
    tVHAB_Objects.System{iSystem}.csChildren   = cell(0);
end

% First we initialize the phase parameters for the stores
for iStore = 1:length(tVHAB_Objects.Store)
    for iPhaseType = 1:length(csPhases)
        tVHAB_Objects.Store{iStore}.(csPhases{iPhaseType}) = cell(0);
    end
end

% We have to start with phases because they are added to the corresponding
% tVHAB_Objects.Store entry and this must be done before the store is added
% to the system
for iPhaseType = 1:length(csPhases)
    sPhase = (csPhases{iPhaseType});
    for iPhase = 1:length(tVHAB_Objects.(sPhase))
        
        tVHAB_Objects.(sPhase){iPhase}.Manipulators = cell.empty;
        for iManip = 1:length(tVHAB_Objects.Manipulator)
            if strcmp(tVHAB_Objects.(sPhase){iPhase}.id, tVHAB_Objects.Manipulator{iManip}.ParentID)
                tVHAB_Objects.(sPhase){iPhase}.Manipulators{end+1} = tVHAB_Objects.Manipulator{iManip};
            end
        end
        
        tVHAB_Objects.(sPhase){iPhase}.HeatSource = cell.empty;
        for iHeatSource = 1:length(tVHAB_Objects.HeatSource)
            if strcmp(tVHAB_Objects.(sPhase){iPhase}.id, tVHAB_Objects.HeatSource{iHeatSource}.ParentID)
                tVHAB_Objects.(sPhase){iPhase}.HeatSource{end+1} = tVHAB_Objects.HeatSource{iHeatSource};
            end
        end
        
        for iStore = 1:length(tVHAB_Objects.Store)
            if strcmp(tVHAB_Objects.(sPhase){iPhase}.ParentID, tVHAB_Objects.Store{iStore}.id)
                 tVHAB_Objects.Store{iStore}.(sPhase){end+1} = tVHAB_Objects.(sPhase){iPhase};
            end
        end
    end
end

% Add stores to systems
for iSystem = 1:length(tVHAB_Objects.System)
    tVHAB_Objects.System{iSystem}.Stores = cell(0);
end

for iStore = 1:length(tVHAB_Objects.Store)
    
    tVHAB_Objects.Store{iStore}.P2Ps = cell.empty;
    for iP2P = 1:length(tVHAB_Objects.P2P)
        if strcmp(tVHAB_Objects.Store{iStore}.id, tVHAB_Objects.P2P{iP2P}.ParentID)
            tVHAB_Objects.Store{iStore}.P2Ps{end+1} = tVHAB_Objects.P2P{iP2P};
        end
    end
    
    for iSystem = 1:length(tVHAB_Objects.System)
        if strcmp(tVHAB_Objects.Store{iStore}.ParentID, tVHAB_Objects.System{iSystem}.id)
            tVHAB_Objects.System{iSystem}.Stores{end+1} = tVHAB_Objects.Store{iStore};
        end
    end
end

for iSystem = 1:length(tVHAB_Objects.System)
    tVHAB_Objects.System{iSystem}.FoodStores = cell(0);
end

for iFoodStore = 1:length(tVHAB_Objects.FoodStore)
    for iSystem = 1:length(tVHAB_Objects.System)
        if strcmp(tVHAB_Objects.FoodStore{iFoodStore}.ParentID, tVHAB_Objects.System{iSystem}.id)
            tVHAB_Objects.System{iSystem}.FoodStores{end+1} = tVHAB_Objects.FoodStore{iFoodStore};
        end
    end
end

% Add branches to systems
for iSystem = 1:length(tVHAB_Objects.System)
    tVHAB_Objects.System{iSystem}.Branches = cell(0);
end

for iBranch = 1:length(tVHAB_Objects.Branch)
    for iSystem = 1:length(tVHAB_Objects.System)
        if strcmp(tVHAB_Objects.Branch{iBranch}.ParentID, tVHAB_Objects.System{iSystem}.id)
            tVHAB_Objects.System{iSystem}.Branches{end+1} = tVHAB_Objects.Branch{iBranch};
        end
    end
end

for iSystem = 1:length(tVHAB_Objects.System)
    tVHAB_Objects.System{iSystem}.ThermalBranches = cell(0);
end
for iThermalBranch = 1:length(tVHAB_Objects.ThermalBranch)
    for iSystem = 1:length(tVHAB_Objects.System)
        if strcmp(tVHAB_Objects.ThermalBranch{iThermalBranch}.ParentID, tVHAB_Objects.System{iSystem}.id)
            tVHAB_Objects.System{iSystem}.ThermalBranches{end+1} = tVHAB_Objects.ThermalBranch{iThermalBranch};
        end
    end
end

% Add f2f components to systems
% First we initialize the phase parameters for the stores
for iSystem = 1:length(tVHAB_Objects.System)
    for iF2FType = 1:length(csF2F)
        tVHAB_Objects.System{iSystem}.(csF2F{iF2FType}) = cell(0);
    end
end

for iF2FType = 1:length(csF2F)
    sF2F = (csF2F{iF2FType});
    for iF2F = 1:length(tVHAB_Objects.(sF2F))
        for iSystem = 1:length(tVHAB_Objects.System)
            if strcmp(tVHAB_Objects.(sF2F){iF2F}.ParentID, tVHAB_Objects.System{iSystem}.id)
                
                for iCheckF2F = 1:length(tVHAB_Objects.System{iSystem}.(sF2F))
                    if strcmp(tVHAB_Objects.(sF2F){iF2F}.label, tVHAB_Objects.System{iSystem}.(sF2F){iCheckF2F}.label)
                        % If the name is already taken, append a number to
                        % identify the F2Fs and change the corresponding
                        % label in the F2F structs accordingly
                        sLabel = tVHAB_Objects.(sF2F){iF2F}.label;
                        sLastThreeDigits = sLabel(end-2:end);
                        if all(ismember(sLastThreeDigits, '0123456789'))
                            iCurrentNumber = str2num(sLastThreeDigits);
                            iCurrentNumber = iCurrentNumber + 1;
                            sLabel = sLabel(1:end-3);
                            if iCurrentNumber < 10
                                sLabel = [sLabel, '00', num2str(iCurrentNumber)];
                            elseif iCurrentNumber < 100
                                sLabel = [sLabel, '0', num2str(iCurrentNumber)];
                            end
                        else
                            sLabel = [sLabel, '_001'];
                        end
                        tVHAB_Objects.(sF2F){iF2F}.label = sLabel;
                    end
                end
                tVHAB_Objects.System{iSystem}.(sF2F){end+1} = tVHAB_Objects.(sF2F){iF2F};
            end
        end
    end
end

% Connect in and outputs to the corresponding library subsystems
for iSystem = 1:length(tVHAB_Objects.System)
    for iSubsystemType = 1:length(csSystems)
        tVHAB_Objects.System{iSystem}.(csSystems{iSubsystemType}) = cell(0);
    end
end

for iSubsystemType = 1:length(csSystems)
    for iSubsystem = 1:length(tVHAB_Objects.(csSystems{iSubsystemType}))
        
        tVHAB_Objects.(csSystems{iSubsystemType}){iSubsystem}.Input    = cell(0);
        tVHAB_Objects.(csSystems{iSubsystemType}){iSubsystem}.Output   = cell(0);
        
        for iInput = 1:length(tVHAB_Objects.Input)
            if strcmp(tVHAB_Objects.(csSystems{iSubsystemType}){iSubsystem}.id, tVHAB_Objects.Input{iInput}.ParentID)
                tVHAB_Objects.(csSystems{iSubsystemType}){iSubsystem}.Input{end+1} = tVHAB_Objects.Input{iInput};
            end
        end
        for iOutput = 1:length(tVHAB_Objects.Output)
            if strcmp(tVHAB_Objects.(csSystems{iSubsystemType}){iSubsystem}.id, tVHAB_Objects.Output{iOutput}.ParentID)
                tVHAB_Objects.(csSystems{iSubsystemType}){iSubsystem}.Output{end+1} = tVHAB_Objects.Output{iOutput};
            end
        end
    end
end

for iSystem = 1:length(tVHAB_Objects.System)
    for iSupraSystem = 1:length(tVHAB_Objects.System)
        sSupraSystemID = tVHAB_Objects.System{iSystem}.ParentID;
        
        if strcmp(tVHAB_Objects.System{iSupraSystem}.id, sSupraSystemID)
            tVHAB_Objects.System{iSupraSystem}.csChildren{end+1} = tVHAB_Objects.System{iSystem};
        end
    end
    
    % loop through the possible library subsystems and check if they are
    % part of the system
    for iSubsystemType = 1:length(csSystems)
        for iSubsystem = 1:length(tVHAB_Objects.(csSystems{iSubsystemType}))
            
            if strcmp(tVHAB_Objects.System{iSystem}.id, tVHAB_Objects.(csSystems{iSubsystemType}){iSubsystem}.ParentID)
                if ~isfield(tVHAB_Objects.System{iSystem}, csSystems{iSubsystemType})
                    tVHAB_Objects.System{iSystem}.(csSystems{iSubsystemType}) = cell(0);
                end
                tVHAB_Objects.System{iSystem}.(csSystems{iSubsystemType}){end+1} =  tVHAB_Objects.(csSystems{iSubsystemType}){iSubsystem};
            end
        end
    end
end
end