function importPlantData(this)
% importPlantData Imports data for the plant matter composition from the
% plant model and creates the corresponding compound masses

    [ ttxImportPlantParameters ] = components.matter.PlantModule.plantparameters.importPlantParameters();
    
    csPlants = fieldnames(ttxImportPlantParameters);
    
    % loop over all Plants
    for iJ = 1:length(csPlants)
        % The edible plant part is created by the importNutrientData
        % function, we just have to handle the inedible part, which is
        % simple because it just uses very basic assumptions:
        
        % Inedible is just assume to have this composition for all plants
        trBaseCompositionInedible.Biomass   = 0.1;
        % For the base nitrate content 3 mg / kg of dry weight are
        % assumed. So if 1 kg of wet weight has 0.1 kg of dry mass, then it
        % should contain 0.3 mg or 3e-4 kg
        trBaseCompositionInedible.NO3       = 3e-4;
        trBaseCompositionInedible.H2O       = 0.9 - trBaseCompositionInedible.NO3;
        
        % Now we define a compound mass in the matter table with the
        % corresponding composition. Note that the base composition can be
        % adjusted within a simulation, but for defining matter of this
        % type, the base composition is used
        this.defineCompoundMass(this, [csPlants{iJ}, 'Inedible'],   trBaseCompositionInedible)
    end

end