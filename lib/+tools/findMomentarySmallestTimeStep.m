function [ ] = findMomentarySmallestTimeStep( oLastSimObj )
% findMomentarySmallestTimeStep displays the smallest time step and the
% phase, store and system in which it occurs for the CURRENT TICK!

    %% Highest Mass Loss
    iNumberOfPhases = length(oLastSimObj.oSimulationContainer.oMT.aoPhases);
    afTimeStep_in_Phases = reshape([ oLastSimObj.oSimulationContainer.oMT.aoPhases.fTimeStep ], [1,iNumberOfPhases]);
    
    miMinTimeStepIndices = find(afTimeStep_in_Phases == min(afTimeStep_in_Phases));

    aoPhases = oLastSimObj.oSimulationContainer.oMT.aoPhases;
    
    disp(' ')
    disp('The smallest time steps for the current tick occured in:') 
    for iI = 1:length(miMinTimeStepIndices)
        % returns the system name, store name and phase name for the location
        % where the highes mass losses occured
        disp(['The system ', aoPhases(miMinTimeStepIndices(iI)).oStore.oContainer.sName, ' in Store ', aoPhases(miMinTimeStepIndices(iI)).oStore.sName, ' in Phase ', aoPhases(miMinTimeStepIndices(iI)).sName, ' a minimal time step of ' num2str(aoPhases(miMinTimeStepIndices(iI)).fTimeStep), ' was used'])
        
    end
end

