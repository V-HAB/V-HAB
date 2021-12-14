function tCurrentSystem = createBranches(tCurrentSystem, tVHAB_Objects, csSystems, sSystemFile)
%% Create Branches
% This functions creates all branches and defines the necessary interfaces
% between systems for the branches

% We now check what branches connect to phases in the current system.
% This also includes interface branches between the different systems
% TO DO: probably connecting two subsystems directly will not work in
% the initial implementation

fprintf(sSystemFile, '         %s Creating the branches\n', '%%');
for iBranch = 1:length(tCurrentSystem.csBranches)
    sBranch = tCurrentSystem.csBranches{iBranch};
    
    fprintf(sSystemFile, [sBranch, '\n']);
end
fprintf(sSystemFile, '\n');


%% Create Interfaces
tcsParentSideInterfaces = struct();
csChildSideInterfaces = cell(0);
for iInterface = 1:length(tCurrentSystem.csInterfaces)
    if strcmp(tCurrentSystem.csInterfaceIDs{iInterface}{2} ,tCurrentSystem.id)
        % we are the right side and therefore the parent
        for iChild = 1:length(tVHAB_Objects.System)
            if strcmp(tCurrentSystem.csInterfaceIDs{iInterface}{1}, tVHAB_Objects.System{iChild}.id)
                
                if ~isfield(tcsParentSideInterfaces, tVHAB_Objects.System{iChild}.label)
                    tcsParentSideInterfaces.(tVHAB_Objects.System{iChild}.label) = cell(0);
                end
                tcsParentSideInterfaces.(tVHAB_Objects.System{iChild}.label){end+1} = tCurrentSystem.csInterfaces{iInterface}{1};
                break
            end
        end
        
    elseif  strcmp(tCurrentSystem.csInterfaceIDs{iInterface}{1} ,tCurrentSystem.id)
        % we are the left side and therefore the child system
        csChildSideInterfaces{end+1} = tCurrentSystem.csInterfaces{iInterface}{2};
    else
        error('Something went wrong during interface definition')
    end
end

csChildren = fieldnames(tcsParentSideInterfaces);
for iChild = 1:length(csChildren)
    if ~isempty(tcsParentSideInterfaces.(csChildren{iChild}))
        
        sSetInterfaces = ['this.toChildren.', csChildren{iChild},'.setIfFlows('];
        csIFs = tcsParentSideInterfaces.(csChildren{iChild});
        for iParentIF = 1:length(csIFs)
            sSetInterfaces = [sSetInterfaces, csIFs{iParentIF}, ', '];
        end
        sSetInterfaces = sSetInterfaces(1:end-2);
        sSetInterfaces = [sSetInterfaces, ');\n'];
        
        fprintf(sSystemFile, sSetInterfaces);
    end
end


% Definition of the interfaces with the names from the xml drawing but the
% order of the subsystem IF definition function
tInterfaces.Human           = {'Air_Out', 'Air_In', 'Water_In', 'Food_In', 'Feces_Out', 'Urine_Out'};
tInterfaces.CDRA            = {'Air_In', 'Air_Out', 'CO2_Out'};
tInterfaces.OGA             = {'Water_In', 'O2_Out', 'H2_Out'};
tInterfaces.SCRA            = {'H2_In', 'CO2_In', 'Gas_Out', 'Condensate_Out', 'Coolant_In', 'Coolant_Out'};
tInterfaces.Plants          = {'Air_In', 'Air_Out', 'Nutrient_In', 'Nutrient_Out', 'Biomass_Out'};
tInterfaces.HFC             = {'Air_In', 'Air_Out'};
tInterfaces.Electrolyzer    = {'H2_Out', 'O2_Out', 'Water_In', 'Coolant_Out', 'Coolant_In'};
tInterfaces.FuelCell        = {'H2_In',  'H2_Out', 'O2_In', 'O2_Out', 'Coolant_In', 'Coolant_Out', 'Water_Out'};
tInterfaces.WPA             = {'Water_In', 'Water_Out', 'Air_In', 'Air_Out'};
tInterfaces.UPA             = {'Urine_In', 'Water_Out', 'Brine_Out'};
tInterfaces.BPA             = {'Brine_In', 'Air_In', 'Air_Out'};
tInterfaces.CROP            = {'Urine_In', 'Solution_Out', 'Air_In', 'Air_Out', 'Calcite_In'};
            
csSubsystemTypes = fieldnames(tInterfaces);

for iSubsystemType = 1:length(csSystems)
    sSubsystemType = csSystems{iSubsystemType};
    for iSubsystem = 1:length(tCurrentSystem.(sSubsystemType))
        tSubsystem = tCurrentSystem.(csSystems{iSubsystemType}){iSubsystem};
        
        
        if strcmp(sSubsystemType, 'Human')
            fprintf(sSystemFile, '%%%% Human Interfaces\n');
            
            fprintf(sSystemFile, ['oCabinPhase          = ', tSubsystem.toInterfacePhases.oCabin,';\n']);
            fprintf(sSystemFile, ['oPotableWaterPhase   = ', tSubsystem.toInterfacePhases.oWater,';\n']);
            fprintf(sSystemFile, ['oFecesPhase          = ', tSubsystem.toInterfacePhases.oFeces,';\n']);
            fprintf(sSystemFile, ['oUrinePhase          = ', tSubsystem.toInterfacePhases.oUrine,';\n']);
            fprintf(sSystemFile, ['oFoodStore           = this.toStores.', tSubsystem.toInterfacePhases.oFoodStore,';\n']);
            fprintf(sSystemFile, '\n');
            fprintf(sSystemFile, 'for iHuman = 1:this.iCrewMembers\n');
            fprintf(sSystemFile, '  %% Add Exmes for each human\n');
            fprintf(sSystemFile, '  matter.procs.exmes.gas(oCabinPhase,             [''AirOut'',      num2str(iHuman)]);\n');
            fprintf(sSystemFile, '  matter.procs.exmes.gas(oCabinPhase,             [''AirIn'',       num2str(iHuman)]);\n');
            fprintf(sSystemFile, '  matter.procs.exmes.liquid(oPotableWaterPhase,   [''DrinkingOut'', num2str(iHuman)]);\n');
            fprintf(sSystemFile, '  matter.procs.exmes.mixture(oFecesPhase,         [''Feces_In'',    num2str(iHuman)]);\n');
            fprintf(sSystemFile, '  matter.procs.exmes.mixture(oUrinePhase,         [''Urine_In'',    num2str(iHuman)]);\n');
            fprintf(sSystemFile, '  matter.procs.exmes.gas(oCabinPhase,             [''Perspiration'',num2str(iHuman)]);\n');
            fprintf(sSystemFile, '\n');
            fprintf(sSystemFile, '  %% Add interface branches for each human\n');
            fprintf(sSystemFile, '  matter.branch(this, [''Air_Out'',         num2str(iHuman)],  	{}, [oCabinPhase.oStore.sName,             ''.AirOut'',      num2str(iHuman)]);\n');
            fprintf(sSystemFile, '  matter.branch(this, [''Air_In'',          num2str(iHuman)], 	{}, [oCabinPhase.oStore.sName,             ''.AirIn'',       num2str(iHuman)]);\n');
            fprintf(sSystemFile, '  matter.branch(this, [''Feces'',           num2str(iHuman)],  	{}, [oFecesPhase.oStore.sName,             ''.Feces_In'',    num2str(iHuman)]);\n');
            fprintf(sSystemFile, '  matter.branch(this, [''PotableWater'',    num2str(iHuman)], 	{}, [oPotableWaterPhase.oStore.sName,      ''.DrinkingOut'', num2str(iHuman)]);\n');
            fprintf(sSystemFile, '  matter.branch(this, [''Urine'',           num2str(iHuman)], 	{}, [oUrinePhase.oStore.sName,             ''.Urine_In'',    num2str(iHuman)]);\n');
            fprintf(sSystemFile, '  matter.branch(this, [''Perspiration'',    num2str(iHuman)], 	{}, [oCabinPhase.oStore.sName,             ''.Perspiration'',num2str(iHuman)]);\n');
            fprintf(sSystemFile, '  \n');
            fprintf(sSystemFile, '  %% register each human at the food store\n');
            fprintf(sSystemFile, '  requestFood = oFoodStore.registerHuman([''Solid_Food_'', num2str(iHuman)]);\n');
            fprintf(sSystemFile, '  this.toChildren.([''Human_'', num2str(iHuman)]).toChildren.Digestion.bindRequestFoodFunction(requestFood);\n');
            fprintf(sSystemFile, '  \n');
            fprintf(sSystemFile, '  %% Set the interfaces for each human\n');
            fprintf(sSystemFile, '  this.toChildren.([''Human_'',         num2str(iHuman)]).setIfFlows(...\n');
            fprintf(sSystemFile, '                  [''Air_Out'',         num2str(iHuman)],...\n');
            fprintf(sSystemFile, '                  [''Air_In'',          num2str(iHuman)],...\n');
            fprintf(sSystemFile, '                  [''PotableWater'',    num2str(iHuman)],...\n');
            fprintf(sSystemFile, '                  [''Solid_Food_'',     num2str(iHuman)],...\n');
            fprintf(sSystemFile, '                  [''Feces'',           num2str(iHuman)],...\n');
            fprintf(sSystemFile, '                  [''Urine'',           num2str(iHuman)],...\n');
            fprintf(sSystemFile, '                  [''Perspiration'',    num2str(iHuman)]);\n');
            fprintf(sSystemFile, 'end\n');
            fprintf(sSystemFile, '  \n');
        elseif strcmp(sSubsystemType, 'Plants')
            
            fprintf(sSystemFile, '\n');
            fprintf(sSystemFile, '%%%% Plant Interfaces\n');
            
            fprintf(sSystemFile, ['oGreenhousePhase     = ', tSubsystem.toInterfacePhases.oCabin,';\n']);
            fprintf(sSystemFile, ['oNutrientSupply      = ', tSubsystem.toInterfacePhases.oNutrient,';\n']);
            fprintf(sSystemFile, ['oEdibleSplit         = ', tSubsystem.toInterfacePhases.oBiomass,';\n']);
            fprintf(sSystemFile, '\n');
            fprintf(sSystemFile, 'for iPlant = 1:length(this.csPlants)\n');
            fprintf(sSystemFile, '  for iSubculture = 1:this.miSubcultures(iPlant)\n');
            fprintf(sSystemFile, '      sCultureName = [this.csPlants{iPlant},''_'', num2str(iSubculture)];\n');
            fprintf(sSystemFile, '      \n');
            fprintf(sSystemFile, '      matter.procs.exmes.gas(oGreenhousePhase,     	[sCultureName, ''_AtmosphereCirculation_Out'']);\n');
            fprintf(sSystemFile, '      matter.procs.exmes.gas(oGreenhousePhase,       	[sCultureName, ''_AtmosphereCirculation_In'']);\n');
            fprintf(sSystemFile, '      matter.procs.exmes.liquid(oNutrientSupply,     	[sCultureName, ''_to_NFT'']);\n');
            fprintf(sSystemFile, '      matter.procs.exmes.liquid(oNutrientSupply,    	[sCultureName, ''_from_NFT'']);\n');
            fprintf(sSystemFile, '      matter.procs.exmes.mixture(oEdibleSplit,       	[sCultureName, ''_Biomass_In'']);\n');
            fprintf(sSystemFile, '      \n');
            fprintf(sSystemFile, '      matter.branch(this, [sCultureName, ''_Atmosphere_ToIF_Out''],      {}, [oGreenhousePhase.oStore.sName,      ''.'',	sCultureName, ''_AtmosphereCirculation_Out'']);\n');
            fprintf(sSystemFile, '      matter.branch(this, [sCultureName, ''_Atmosphere_FromIF_In''],     {}, [oGreenhousePhase.oStore.sName,      ''.'',	sCultureName, ''_AtmosphereCirculation_In'']);\n');
            fprintf(sSystemFile, '      matter.branch(this, [sCultureName, ''_WaterSupply_ToIF_Out''],     {}, [oNutrientSupply.oStore.sName,       ''.'',	sCultureName, ''_to_NFT'']);\n');
            fprintf(sSystemFile, '      matter.branch(this, [sCultureName, ''_NutrientSupply_ToIF_Out''],  {}, [oNutrientSupply.oStore.sName,       ''.'',  sCultureName, ''_from_NFT'']);\n');
            fprintf(sSystemFile, '      matter.branch(this, [sCultureName, ''_Biomass_FromIF_In''],        {}, [oEdibleSplit.oStore.sName,          ''.'',  sCultureName, ''_Biomass_In'']);\n');
            fprintf(sSystemFile, '      \n');
            fprintf(sSystemFile, '      this.toChildren.(sCultureName).setIfFlows(...\n');
            fprintf(sSystemFile, '           	[sCultureName, ''_Atmosphere_ToIF_Out''], ...\n');
            fprintf(sSystemFile, '           	[sCultureName ,''_Atmosphere_FromIF_In''], ...\n');
            fprintf(sSystemFile, '           	[sCultureName ,''_WaterSupply_ToIF_Out''], ...\n');
            fprintf(sSystemFile, '           	[sCultureName ,''_NutrientSupply_ToIF_Out''], ...\n');
            fprintf(sSystemFile, '           	[sCultureName ,''_Biomass_FromIF_In'']);\n');
            fprintf(sSystemFile, '	end\n');
            fprintf(sSystemFile, 'end\n');
            fprintf(sSystemFile, '\n');
            
        else
            % The CCAA has a variable number of outputs
            if strcmp(sSubsystemType, 'CCAA')
                if isempty(tSubsystem.sCDRA)
                    tInterfaces.CCAA = {'Air_In', 'Air_Out', 'Condensate_Out', 'Coolant_In', 'Coolant_Out'};
                else
                    tInterfaces.CCAA = {'Air_In', 'Air_Out', 'Condensate_Out', 'Coolant_In', 'Coolant_Out', 'CDRA_Air_Out'};
                end
            end

            csInterfaces = cell.empty();
            if strcmp(sSubsystemType, 'Subsystem')
                for iGenericSubsystemType = 1:length(csSubsystemTypes)
                    if ~isempty(regexp(tSubsystem.sSubsystemPath, csSubsystemTypes{iGenericSubsystemType}, 'once'))
                        csInterfaces = tInterfaces.(csSubsystemTypes{iGenericSubsystemType});
                    end
                end
                if isempty(csInterfaces)
                    error('unknown subsystem type was used')
                end
            else
                csInterfaces = tInterfaces.(sSubsystemType);
            end
            
            csFinalInterfaces = cell(1,length(csInterfaces));
            for iInterface = 1:length(csInterfaces)

                sInterface = csInterfaces{iInterface};
                csFields = textscan(sInterface,'%s','Delimiter','_');
                csFields = csFields{1};
                sInterfaceType = csFields{end};
                sInterface = sInterface(1:end-(length(sInterfaceType) + 1));

                if strcmp(sInterfaceType, 'In')
                     for iInput = 1:length(tSubsystem.Input)
                        tInput = tSubsystem.Input{iInput};
                        if ~isempty(regexp(tInput.label, sInterface, 'once'))
                            csFinalInterfaces{iInterface} = ['''', tSubsystem.label, '_', tInput.label, '_In'''];
                        end
                     end
                else
                     for iOutput = 1:length(tSubsystem.Output)
                        tOutput = tSubsystem.Output{iOutput};
                        % now check if the label is represented accuratly
                        % to prevent Air_Out and XX_Air_Out to be added
                        % twice
                        if strcmp(tOutput.label, sInterface)
                            csFinalInterfaces{iInterface} = ['''', tSubsystem.label, '_', tOutput.label, '_Out'''];
                        end
                     end
                end
            end
            % now we have all interface and have to define the IF definition

            sInterfaceDefinition = ['this.toChildren.', tSubsystem.label, '.setIfFlows('];
            for iInterface = 1:length(csInterfaces)
                sInterfaceDefinition = [sInterfaceDefinition, csFinalInterfaces{iInterface}, ', '];
            end
            sInterfaceDefinition = sInterfaceDefinition(1:end-2);
            sInterfaceDefinition = [sInterfaceDefinition, ');\n'];

            fprintf(sSystemFile, sInterfaceDefinition);
        end
    end
end

fprintf(sSystemFile, '     	end\n\n');
fprintf(sSystemFile, '      function setIfFlows(this, varargin)\n');

for iChildIF = 1:length(csChildSideInterfaces)
    sChildInterface = ['this.connectIF(', csChildSideInterfaces{iChildIF},', varargin{' num2str(iChildIF), '});\n'];
    fprintf(sSystemFile, sChildInterface);
end

fprintf(sSystemFile, '      end\n\n');
end