function [ ] = findMassErrors( oLastSimObj )
% FINDMASSBALANCEERRORS displays system, store and phase name for the phases
% with the highes mass balance errors. Uses oLastSimObj as input

    %% Highest Mass Loss
    afMassLost_in_Phases = reshape([ oLastSimObj.oSimulationContainer.oMT.aoPhases.afMassLost ], oLastSimObj.oSimulationContainer.oMT.iSubstances, []);

    fMassLost_in_Phases = sum(afMassLost_in_Phases);

    miMaxLostIndices = find(fMassLost_in_Phases == max(fMassLost_in_Phases));

    aoPhases = oLastSimObj.oSimulationContainer.oMT.aoPhases;
    
    disp(' ')
    disp('The highest mass losses occured in:') 
    for iI = 1:length(miMaxLostIndices)
        % returns the system name, store name and phase name for the location
        % where the highes mass losses occured
        disp(['The system ', aoPhases(miMaxLostIndices(iI)).oStore.oContainer.sName, ' in Store ', aoPhases(miMaxLostIndices(iI)).oStore.sName, ' in Phase ', aoPhases(miMaxLostIndices(iI)).sName, ' a total of ' num2str(sum(aoPhases(miMaxLostIndices(iI)).afMassLost)), ' kg mass was lost'])
        
    end
end

