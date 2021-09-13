function tVHAB_Objects = convertBranches(tVHAB_Objects, csPhases, csF2F, csSystems, tConvertIDs)
%% Convert drawio branches to V-HAB branches
% in draw io every arrow is considered a branch, this is not true in V-HAB,
% where a branch has to start at a phase and end at a phase (with possible
% interfaces in between). This function is used to convert the draw io
% arrows and their asscociated components into a more V-HAB conform
% structure

for iSystem = 1:length(tVHAB_Objects.System)
    tVHAB_Objects.System{iSystem}.csBranches        = cell(0);
    tVHAB_Objects.System{iSystem}.cVHABBranches     = cell(0);
    tVHAB_Objects.System{iSystem}.csSolvers         = cell(0);
    tVHAB_Objects.System{iSystem}.csBranchNames    	= cell(0);
    tVHAB_Objects.System{iSystem}.csInterfaces      = cell(0);
    tVHAB_Objects.System{iSystem}.csInterfaceIDs    = cell(0);
end

for iBranch = 1:length(tVHAB_Objects.Branch)
    sLeftSideBranch             = [];
    sRightSideBranch            = [];
    sLeftSideSystemID           = [];
    sRightSideSystemID          = [];
    sLeftSideInterface          = [];
    sRightSideInterface       	= [];
    csF2FinBranches             = cell(0);
    tBranch = tVHAB_Objects.Branch{iBranch};
    
    if isfield(tBranch, 'sCustomName')
        sCustomName = tBranch.sCustomName;
    else
        sCustomName = [];
    end
    
    for iStore = 1:length(tVHAB_Objects.Store)
        tStore = tVHAB_Objects.Store{iStore};
        for iPhaseType = 1:length(csPhases)
            sPhase = (csPhases{iPhaseType});
            for iPhase = 1:length(tStore.(sPhase))

                tPhase = tStore.(sPhase){iPhase};

                if strcmp(tPhase.id, tBranch.SourceID)
                    sLeftSideBranch = ['this.toStores.', tools.normalizePath(tStore.label), '.toPhases.', tools.normalizePath(tPhase.label)];
                    
                    sLeftSideSystemID = tStore.ParentID;
                    
                    sLeftSideInterface = ['''', tConvertIDs.tIDtoLabel.(sLeftSideSystemID), '_', tools.normalizePath(tStore.label), '_', tools.normalizePath(tPhase.label), ''''];
                    
                    
                    % We use the first branch to define the solver of the
                    % V-HAB branch
                    sSolver = tBranch.sSolver;
                    tLeftBranch = tBranch;
                    
                elseif strcmp(tPhase.id, tBranch.TargetID)
                    sRightSideBranch = ['this.toStores.', tools.normalizePath(tStore.label), '.toPhases.', tools.normalizePath(tPhase.label)];

                    sRightSideSystemID = tStore.ParentID;

                    sRightSideInterface = ['''', tConvertIDs.tIDtoLabel.(sRightSideSystemID), '_', tools.normalizePath(tStore.label), '_', tools.normalizePath(tPhase.label), ''''];
                end
            end
        end
    end
    bLeftSideInterface  = false;
    % Special branches are created seperatly e.g. for the human and plant
    % models
    bSpecialBranch      = false;
    
    if isempty(sLeftSideBranch)
        
        for iSubsystemType = 1:length(csSystems)
            for iSubsytem = 1:length(tVHAB_Objects.(csSystems{iSubsystemType}))
                
                tSubsystem = tVHAB_Objects.(csSystems{iSubsystemType}){iSubsytem};
                
                for iOutput = 1:length(tSubsystem.Output)
                    tOutput = tSubsystem.Output{iOutput};
                    
                    if strcmp(tOutput.id, tBranch.SourceID)
                        if strcmp(csSystems{iSubsystemType}, 'Human')
                            % Special handling of human subsystem
                            if strcmp(tOutput.label, 'Air')
                                tVHAB_Objects.(csSystems{iSubsystemType}){iSubsytem}.toInterfacePhases.oCabin = sRightSideBranch;
                            elseif strcmp(tOutput.label, 'Urine')
                                tVHAB_Objects.(csSystems{iSubsystemType}){iSubsytem}.toInterfacePhases.oUrine = sRightSideBranch;
                            elseif strcmp(tOutput.label, 'Feces')
                                tVHAB_Objects.(csSystems{iSubsystemType}){iSubsytem}.toInterfacePhases.oFeces = sRightSideBranch;
                            end
                            bSpecialBranch = true;
                        elseif strcmp(csSystems{iSubsystemType}, 'Plants')
                            % Special handling of plant subsystem
                            if strcmp(tOutput.label, 'Air')
                                tVHAB_Objects.(csSystems{iSubsystemType}){iSubsytem}.toInterfacePhases.oCabin = sRightSideBranch;
                            elseif strcmp(tOutput.label, 'Nutrient')
                                tVHAB_Objects.(csSystems{iSubsystemType}){iSubsytem}.toInterfacePhases.oNutrient = sRightSideBranch;
                            elseif strcmp(tOutput.label, 'Biomass')
                                tVHAB_Objects.(csSystems{iSubsystemType}){iSubsytem}.toInterfacePhases.oBiomass = sRightSideBranch;
                            end
                            bSpecialBranch = true;
                        else

                            sLeftSideInterface = ['''', tSubsystem.label, '_', tOutput.label, '_Out'''];
                            sLeftSideBranch = sLeftSideInterface;
                            sLeftSideSystemID = tSubsystem.ParentID;
                            bLeftSideInterface = true;

                        end
                        break
                    end
                end
                
                for iInput = 1:length(tSubsystem.Input)
                    tInput = tSubsystem.Input{iInput};
                    if strcmp(tBranch.TargetID, tInput.id)
                        if iSubsystemType == 1
                            % Special handling of human subsystem
                            if strcmp(tInput.label, 'Food')
                                for iFoodStore = 1:length(tVHAB_Objects.FoodStore)
                                    tFoodStore = tVHAB_Objects.FoodStore{iFoodStore};
                                    if strcmp(tFoodStore.id, tBranch.SourceID)
                                        tVHAB_Objects.(csSystems{iSubsystemType}){iSubsytem}.toInterfacePhases.oFoodStore = tFoodStore.label;
                                    end
                                end
                            end

                            bSpecialBranch = true;
                        end
                    end
                end
            end
        end
    end
    
    if bSpecialBranch
        continue
        % In this case we have a branch without F2Fs
    elseif ~isempty(sLeftSideBranch) && ~isempty(sRightSideBranch)
        if strcmp(sLeftSideSystemID, sRightSideSystemID)
            % The branch is internal to one system, we can define it
            % without interfaces
            for iSystem = 1:length(tVHAB_Objects.System)
                if strcmp(tVHAB_Objects.System{iSystem}.id, sLeftSideSystemID)
                    
                    sBranch = ['matter.branch(this, ', sLeftSideBranch, ', {}, ', sRightSideBranch, ', ''', sCustomName,''');'];
                    
                    tVHAB_Objects.System{iSystem}.csBranches{end+1} = sBranch;
                    if bLeftSideInterface
                        tVHAB_Objects.System{iSystem}.csSolvers{end+1} = [];
                    else
                        tVHAB_Objects.System{iSystem}.csSolvers{end+1}      = sSolver;
                        tVHAB_Objects.System{iSystem}.cVHABBranches{end+1}  = tLeftBranch;
                    end
                    tVHAB_Objects.System{iSystem}.csBranchNames{end+1} = sCustomName;
                    
                end
            end
        else
            for iSystem = 1:length(tVHAB_Objects.System)
                if strcmp(tVHAB_Objects.System{iSystem}.id, sLeftSideSystemID)
                    
                    sBranch = ['matter.branch(this, ', sLeftSideBranch, ', {}, ', sRightSideInterface, ', ''', sCustomName,''');'];
                    
                    tVHAB_Objects.System{iSystem}.csBranches{end+1}     = sBranch;
                    if bLeftSideInterface
                        tVHAB_Objects.System{iSystem}.csSolvers{end+1} = [];
                    else
                        tVHAB_Objects.System{iSystem}.csSolvers{end+1}      = sSolver;
                        tVHAB_Objects.System{iSystem}.cVHABBranches{end+1}  = tLeftBranch;
                    end
                    tVHAB_Objects.System{iSystem}.csBranchNames{end+1} = sCustomName;
                    tVHAB_Objects.System{iSystem}.csInterfaceIDs{end+1} = {sLeftSideSystemID, sRightSideSystemID};
                    tVHAB_Objects.System{iSystem}.csInterfaces{end+1}   = {sLeftSideInterface, sRightSideInterface};
                    
                elseif strcmp(tVHAB_Objects.System{iSystem}.id, sRightSideSystemID)
                    
                    sBranch = ['matter.branch(this, ', sLeftSideInterface, ', {}, ', sRightSideBranch, ', ''', sCustomName,''');'];
                    
                    tVHAB_Objects.System{iSystem}.csBranches{end+1}     = sBranch;
                    tVHAB_Objects.System{iSystem}.csSolvers{end+1}      = [];
                    tVHAB_Objects.System{iSystem}.csBranchNames{end+1}   = sCustomName;
                    tVHAB_Objects.System{iSystem}.csInterfaceIDs{end+1} = {sLeftSideSystemID, sRightSideSystemID};
                    tVHAB_Objects.System{iSystem}.csInterfaces{end+1}   = {sLeftSideInterface, sRightSideInterface};
                end
            end
        end
    % We define all branches from the left to the right side, therefore we
    % only do this if the left side is not empty
    elseif ~isempty(sLeftSideBranch)
        % First we look for the target of the current branch
        
        while isempty(sRightSideBranch)
        
            bTargetFound = false;
            for iF2FType = 1:length(csF2F)
                sF2F = (csF2F{iF2FType});
                for iF2F = 1:length(tVHAB_Objects.(sF2F))
                    tF2F = tVHAB_Objects.(sF2F){iF2F};
                    for iSystemF2F = 1:length(tVHAB_Objects.System)
                        if strcmp(tVHAB_Objects.(sF2F){iF2F}.id, tBranch.TargetID)

                            csF2FinBranches{end+1}          = tF2F;
                            bTargetFound = true;
                            break
                        end
                    end
                    if bTargetFound
                        break
                    end
                end
                if bTargetFound
                    break
                end
            end
            
            for iStore = 1:length(tVHAB_Objects.Store)
                tStore = tVHAB_Objects.Store{iStore};
                for iPhaseType = 1:length(csPhases)
                    sPhase = (csPhases{iPhaseType});
                    for iPhase = 1:length(tStore.(sPhase))

                        tPhase = tStore.(sPhase){iPhase};
                        if strcmp(tPhase.id, tBranch.TargetID)
                            sRightSideBranch = ['this.toStores.', tools.normalizePath(tStore.label), '.toPhases.', tools.normalizePath(tPhase.label)];

                            sRightSideSystemID = tStore.ParentID;

                            sRightSideInterface = ['''', tConvertIDs.tIDtoLabel.(sRightSideSystemID), '_', tools.normalizePath(tStore.label), '_', tools.normalizePath(tPhase.label), ''''];
                        end
                    end
                end
            end
            
            for iFoodStore = 1:length(tVHAB_Objects.FoodStore)
                tFoodStore = tVHAB_Objects.FoodStore{iFoodStore};
                if strcmp(tFoodStore.id, tBranch.TargetID)
                    
                    sRightSideBranch = ['this.toStores.', tools.normalizePath(tFoodStore.label), '.toPhases.Food'];

                    sRightSideSystemID = tFoodStore.ParentID;

                    sRightSideInterface = ['''', tConvertIDs.tIDtoLabel.(sRightSideSystemID), '_', tools.normalizePath(tFoodStore.label), ''''];
                end
            end
            bSpecialBranch = false;
            for iSubsystemType = 1:length(csSystems)
                for iSubsytem = 1:length(tVHAB_Objects.(csSystems{iSubsystemType}))
                    
                    tSubsystem = tVHAB_Objects.(csSystems{iSubsystemType}){iSubsytem};
                    for iInput = 1:length(tSubsystem.Input)
                        tInput = tSubsystem.Input{iInput};
                        if strcmp(tInput.id, tBranch.TargetID)
                            
                            if strcmp(csSystems{iSubsystemType}, 'Human')
                                % Special handling of human subsystem
                                if strcmp(tInput.label, 'Water')
                                    tVHAB_Objects.(csSystems{iSubsystemType}){iSubsytem}.toInterfacePhases.oWater = sLeftSideBranch;
                                end
                                bSpecialBranch      = true;
                                sRightSideBranch    = 'special';
                                
                            elseif strcmp(csSystems{iSubsystemType}, 'Plants')
                                % Special handling of plant subsystem
                                bSpecialBranch = true;
                                sRightSideBranch    = 'special';
                            else
                                sRightSideSystemID  = tSubsystem.ParentID;
                                sRightSideInterface = ['''', tSubsystem.label, '_', tInput.label, '_In'''];
                                sRightSideBranch    = sRightSideInterface;

                                % Since Parent to Subsystem Interface in V-HAB
                                % can only be defined in one direction (but we
                                % want to allow both here) we switch the sides
                                % and the order of the F2Fs in this branch
                                A = sLeftSideBranch;
                                B = sLeftSideInterface;
                                C = sLeftSideSystemID;

                                sLeftSideBranch     = sRightSideBranch;
                                sLeftSideInterface  = sRightSideInterface;
                                sLeftSideSystemID   = sRightSideSystemID;

                                sRightSideBranch    = A;
                                sRightSideInterface = B;
                                sRightSideSystemID  = C;

                                csF2FinBranches = fliplr(csF2FinBranches);

                                bLeftSideInterface = true;
                            end
                            break
                        end
                    end
                end
            end
            
            if bSpecialBranch
                break
            elseif bTargetFound
                % In this case we have to look for the next branch in the
                % loop
                bNextBranchFound = false;
                for iNextBranch = 1:length(tVHAB_Objects.Branch)
                    if strcmp(tVHAB_Objects.Branch{iNextBranch}.SourceID, csF2FinBranches{end}.id)
                        tBranch = tVHAB_Objects.Branch{iNextBranch};
                        bNextBranchFound = true;
                        break
                    end
                end
                if ~bNextBranchFound
                    if isempty(csF2FinBranches)
                        error('There seems to be a branch that does not end at a phase. The left side of the branch is %s.', sLeftSideInterface)
                    else
                        error('There seems to be a branch that does not end at a phase. The left side of the branch is %s and the last F2F of the branch is called %s and is located in the system %s.', sLeftSideInterface, csF2FinBranches{end}.label, tConvertIDs.tIDtoLabel.(csF2FinBranches{end}.ParentID))
                    end
                    
                end
            else
                if isempty(sRightSideBranch)
                    if isempty(csF2FinBranches)
                        error('There seems to be a branch that does not end at a phase. The left side of the branch is %s.', sLeftSideInterface)
                    else
                        error('There seems to be a branch that does not end at a phase. The left side of the branch is %s and the last F2F of the branch is called %s and is located in the system %s.', sLeftSideInterface, csF2FinBranches{end}.label, tConvertIDs.tIDtoLabel.(csF2FinBranches{end}.ParentID))
                    end
                end
            end
            
        end
        
        if bSpecialBranch
            continue
        end
        % Now we have found all parts relevant for the branch and we can
        % define it
        sBranch = ['matter.branch(this, ', sLeftSideBranch, ', {'];
        sCurrentSystemID = sLeftSideSystemID;
        bInterface = false;
        for iF2F = 1:length(csF2FinBranches)
            sF2FLabel = tools.normalizePath(csF2FinBranches{iF2F}.label);
            if strcmp(sCurrentSystemID, csF2FinBranches{iF2F}.ParentID)
                sBranch = [sBranch, '''', sF2FLabel, ''', '];
            else
                for iSystem = 1:length(tVHAB_Objects.System)
                    if strcmp(tVHAB_Objects.System{iSystem}.id, sCurrentSystemID)

                        try
                            sInterface1 = ['''', tConvertIDs.tIDtoLabel.(csF2FinBranches{iF2F-1}.ParentID), '_', tools.normalizePath(csF2FinBranches{iF2F-1}.label), ''''];
                            sInterfaceID1 = csF2FinBranches{iF2F-1}.ParentID;
                        catch
                            sInterface1 = sLeftSideInterface;
                            sInterfaceID1 = sLeftSideSystemID;
                        end
                        sInterface2 = ['''', tConvertIDs.tIDtoLabel.(csF2FinBranches{iF2F}.ParentID), '_', sF2FLabel, ''''];
                        sInterfaceID2 = csF2FinBranches{iF2F}.ParentID;
                        
                        if strcmp(sBranch(end-1:end), ', ')
                            sBranch = sBranch(1:end-2);
                        end
                        sBranch = [sBranch, '}, ', sInterface2, ', ''', sCustomName,''');'];

                        tVHAB_Objects.System{iSystem}.csBranches{end+1}     = sBranch;
                        tVHAB_Objects.System{iSystem}.csSolvers{end+1}      = sSolver;
                        tVHAB_Objects.System{iSystem}.cVHABBranches{end+1}  = tLeftBranch;
                        tVHAB_Objects.System{iSystem}.csBranchNames{end+1}  = sCustomName;
                        
                        if strcmp(sInterfaceID1, sInterfaceID2)
                            error('something went wrong during interface definition. An interface between the same system was detected?')
                        end

                        tVHAB_Objects.System{iSystem}.csInterfaceIDs{end+1} = {sInterfaceID1, sInterfaceID2};
                        tVHAB_Objects.System{iSystem}.csInterfaces{end+1} = {sInterface1, sInterface2};
                        
                        % reset sBranch for the next system
                        sBranch = ['matter.branch(this, ', sInterface1, ', {''',  sF2FLabel, ''', '];
                        sCurrentSystemID = csF2FinBranches{iF2F}.ParentID;
                        
                        bInterface = true;
                        
                        break
                    end
                end
            end
        end
        
        if strcmp(sRightSideSystemID, sCurrentSystemID)
            
            for iSystem = 1:length(tVHAB_Objects.System)
                if strcmp(tVHAB_Objects.System{iSystem}.id, sCurrentSystemID)
                    
                    if strcmp(sBranch(end-1:end), ', ')
                        sBranch = sBranch(1:end-2);
                    end
                    sBranch = [sBranch, '}, ', sRightSideBranch, ', ''', sCustomName,''');'];
                    
                    tVHAB_Objects.System{iSystem}.csBranches{end+1} = sBranch;
                    if bInterface || bLeftSideInterface
                        tVHAB_Objects.System{iSystem}.csSolvers{end+1} = [];
                    else
                        tVHAB_Objects.System{iSystem}.csSolvers{end+1}      = sSolver;
                        tVHAB_Objects.System{iSystem}.cVHABBranches{end+1}  = tLeftBranch;
                    end
                    tVHAB_Objects.System{iSystem}.csBranchNames{end+1} = sCustomName;
                    
                    if bInterface

                        if strcmp(sInterfaceID1, sInterfaceID2)
                            error('something went wrong during interface definition. An interface between the same system was detected?')
                        end

                        tVHAB_Objects.System{iSystem}.csInterfaceIDs{end+1} = {sInterfaceID1, sInterfaceID2};
                        tVHAB_Objects.System{iSystem}.csInterfaces{end+1} = {sInterface1, sInterface2};
                    end
                end
            end
        else
            
            for iSystem = 1:length(tVHAB_Objects.System)
                if strcmp(tVHAB_Objects.System{iSystem}.id, sCurrentSystemID)
                    try
                        sInterface1 = ['''', tConvertIDs.tIDtoLabel.(csF2FinBranches{iF2F-1}.ParentID), '_', tools.normalizePath(csF2FinBranches{iF2F-1}.label), ''''];
                        sInterfaceID1 = csF2FinBranches{iF2F-1}.ParentID;
                    catch
                        sInterface1 = sLeftSideInterface;
                        sInterfaceID1 = sLeftSideSystemID;
                    end
                    sInterface2 = sRightSideInterface;
                    sInterfaceID2 = sRightSideSystemID;
                    
                    if strcmp(sBranch(end-1:end), ', ')
                        sBranch = sBranch(1:end-2);
                    end
                    sBranch = [sBranch, '}, ', sInterface2, ', ''', sCustomName,''');'];
                    
                    tVHAB_Objects.System{iSystem}.csBranches{end+1}     = sBranch;
                    tVHAB_Objects.System{iSystem}.csSolvers{end+1}      = sSolver;
                    tVHAB_Objects.System{iSystem}.cVHABBranches{end+1}  = tLeftBranch;
                    tVHAB_Objects.System{iSystem}.csBranchNames{end+1}  = sCustomName;
                    
                    if strcmp(sInterfaceID1, sInterfaceID2)
                        error('something went wrong during interface definition. An interface between the same system was detected?')
                    end
                    
                    tVHAB_Objects.System{iSystem}.csInterfaceIDs{end+1} = {sInterfaceID1, sInterfaceID2};
                    tVHAB_Objects.System{iSystem}.csInterfaces{end+1} = {sInterface1, sInterface2};
                    
                end
            end
            
            for iSystem = 1:length(tVHAB_Objects.System)
                if strcmp(tVHAB_Objects.System{iSystem}.id, sRightSideSystemID)
            
                    % reset sBranch for the next system
                    sBranch = ['matter.branch(this, ', sInterface1, ', {}, ', sRightSideBranch, ', ''', sCustomName,''');'];
                    tVHAB_Objects.System{iSystem}.csBranches{end+1} = sBranch;
                    tVHAB_Objects.System{iSystem}.csSolvers{end+1}  = [];
                    tVHAB_Objects.System{iSystem}.csBranchNames{end+1} = sCustomName;
                    
                    if strcmp(sInterfaceID1, sInterfaceID2)
                        error('something went wrong during interface definition. An interface between the same system was detected?')
                    end
                    
                    tVHAB_Objects.System{iSystem}.csInterfaceIDs{end+1} = {sInterfaceID1, sInterfaceID2};
                    tVHAB_Objects.System{iSystem}.csInterfaces{end+1} = {sInterface1, sInterface2};
                end
            end     
        end
    else
        % Check if the left side is a f2f
        bLeftF2F = false;
        for iF2FType = 1:length(csF2F)
            sF2F = (csF2F{iF2FType});
            for iF2F = 1:length(tVHAB_Objects.(sF2F))
                tF2F = tVHAB_Objects.(sF2F){iF2F};
                if strcmp(tF2F.id, tBranch.SourceID)
                    bLeftF2F = true;
                end
            end
        end
        if ~bLeftF2F
            % currently it seems like letting the import finish and
            % throwing the V-HAB error makes more sense as the output is
            % more verbose
            % error('we could not find the left side of the branch. Check if the all branches in draw io are connected correctly and if all phases are placed correctly inside the store')
        end
    end
end

% assigning the toInterfacePhases to the other subsystem ref:
for iSystem = 1:length(tVHAB_Objects.System)
    for iHuman = 1:length(tVHAB_Objects.System{iSystem}.Human)
        for iParentRef = 1:length(tVHAB_Objects.Human)
            if strcmp(tVHAB_Objects.Human{iParentRef}.id, tVHAB_Objects.System{iSystem}.Human{iHuman}.id)
                tVHAB_Objects.System{iSystem}.Human{iHuman}.toInterfacePhases = tVHAB_Objects.Human{iParentRef}.toInterfacePhases;
            end
        end
    end
    for iPlant = 1:length(tVHAB_Objects.System{iSystem}.Plants)
        for iParentRef = 1:length(tVHAB_Objects.Plants)
            if strcmp(tVHAB_Objects.Plants{iParentRef}.id, tVHAB_Objects.System{iSystem}.Plants{iPlant}.id)
                tVHAB_Objects.System{iSystem}.Plants{iPlant}.toInterfacePhases = tVHAB_Objects.Plants{iParentRef}.toInterfacePhases;
            end
        end
    end
end
end