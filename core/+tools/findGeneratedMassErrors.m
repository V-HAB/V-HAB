function [ ] = findGeneratedMassErrors( oLastSimObj )
% findMassGeneratedErrors displays system, store and phase name for the phases
% with the highest mass balance errors. Uses oLastSimObj as input

    %% Highest Mass Loss
    aoPhases = oLastSimObj.toMonitors.oMatterObserver.aoPhases;
    afMassGenerated_in_Phases = reshape([ aoPhases.afMassGenerated ], oLastSimObj.oSimulationContainer.oMT.iSubstances, []);

    fMassGenerated_in_Phases = sum(afMassGenerated_in_Phases);

    miMaxLostIndices = find(fMassGenerated_in_Phases == max(fMassGenerated_in_Phases));
    
    disp(' ')
    disp('The highest mass generation occured in:') 
    for iI = 1:length(miMaxLostIndices)
        % returns the system name, store name and phase name for the location
        % where the highes mass losses occured
        disp(['The system ', aoPhases(miMaxLostIndices(iI)).oStore.oContainer.sName, ' in Store ', aoPhases(miMaxLostIndices(iI)).oStore.sName, ' in Phase ', aoPhases(miMaxLostIndices(iI)).sName, ' a total of ' num2str(sum(aoPhases(miMaxLostIndices(iI)).afMassGenerated)), ' kg mass was generated'])
        
    end
    
end

