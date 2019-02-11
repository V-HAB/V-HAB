function [ ] = findGeneratedMassErrors( oLastSimObj )
    %FINDGENERATEDMASSERRORS Debugging tool for mass balance errors 
    % This function displays system, store and phase name for the phase
    % with the highest mass balance error. It uses oLastSimObj as input
    % and is designed to be used when a simulation is completed or paused. 
    %
    % For the function to work the matterObserver monitor needs to be added
    % to the simulation infrastructure. 
    
    % Getting an array of all the phases in the model from the matter
    % observer.
    aoPhases = oLastSimObj.toMonitors.oMatterObserver.aoPhases;
    
    % Combining the afMassGenerated arrays in the phases into a matrix. 
    mfMassGeneratedInPhases = reshape([ aoPhases.afMassGenerated ], oLastSimObj.oSimulationContainer.oMT.iSubstances, []);

    % Calculating the sum of all generated mass per phase.
    afMassGeneratedInPhases = sum(mfMassGeneratedInPhases);
    
    % Finding the index of the phase that has the highest mass balance
    % error. Since it is possible that two phases have the exact same
    % error, the variable is an array and find will then return two (or
    % more) indexes. 
    aiMaxLostIndexes = find(afMassGeneratedInPhases == max(afMassGeneratedInPhases));
    
    % Some user printouts
    disp(' ')
    disp('The highest mass generation occured in:') 
    
    % Looping through all phases with the maximum mass error and displaying
    % their information.
    for iI = 1:length(aiMaxLostIndexes)
        % Printing the system name, store name and phase name for the
        % location where the highest mass losses occured
        disp(['The system ', aoPhases(aiMaxLostIndexes(iI)).oStore.oContainer.sName, ' in Store ', aoPhases(aiMaxLostIndexes(iI)).oStore.sName, ' in Phase ', aoPhases(aiMaxLostIndexes(iI)).sName, ' a total of ' num2str(sum(aoPhases(aiMaxLostIndexes(iI)).afMassGenerated)), ' kg mass was generated'])
        
    end
    
end

